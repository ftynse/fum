//===- DepOps.cpp - Dep dialect ops -----------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Dep/IR/DepOps.h"
#include "fum/Dialect/Dep/IR/DepDialect.h"
#include "fum/Dialect/Dep/Interfaces/DepOpInterfaces.h"
#include "fum/Dialect/Dep/Interfaces/DepTypeInteraces.h"
#include "mlir/IR/Visitors.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Support/LogicalResult.h"

using namespace mlir;
using namespace mlir::dep;

#define GET_OP_CLASSES
#include "fum/Dialect/Dep/IR/DepOps.cpp.inc"

// Verify the 'binds' attribute of an op implementing the dep binder interface.
template <typename OpTy>
static LogicalResult verifyDepBinderOp(OpTy op) {
  for (Attribute attr : op.getBinds().getValue()) {
    auto subArray = dyn_cast<ArrayAttr>(attr);
    if (!subArray || subArray.size() != 2)
      return op.emitError()
             << "expects 'binds' to be an array of size-two arrays";
    auto positionAttr = dyn_cast<IntegerAttr>(subArray[0]);
    if (!positionAttr)
      return op.emitError()
             << "expects the first entry of each pair in 'binds' "
                "to be an integer, got "
             << subArray[0];
    int64_t position = positionAttr.getInt();
    int64_t maxPosition = op.getMaxBindablePosition();
    if (position >= maxPosition)
      return op.emitError() << "binder position " << position
                            << " is out of bounds, the op only binds "
                            << maxPosition << " values to parameters";

    Type boundValueType = op.getBoundValueType(position);
    if (!isa<DepTypeParamInterface>(boundValueType))
      return op.emitError() << "value bound to dependent type parameter '"
                            << subArray[1] << "' has type " << boundValueType
                            << " not allowed as dependent type parameter";

    if (!isa<StringAttr>(subArray[1]))
      return op.emitError() << "expects the second entry of each pair in "
                               "'binds' to be a string, got "
                            << subArray[1];
  }
  return success();
}

// Verify the 'requires' and 'ensures' regions of a binder operation.
// `inputTypes` contains the types of values that may be bound, in order.
template <typename OpTy>
static LogicalResult verifyDepBinderAuxRegions(OpTy op, TypeRange inputTypes) {
  SmallVector<Type> parameterTypes;
  parameterTypes.reserve(inputTypes.size());
  llvm::SmallDenseSet<int64_t> dependentParamPositions;
  for (auto sub : op.getBinds().template getAsValueRange<ArrayAttr>()) {
    dependentParamPositions.insert(cast<IntegerAttr>(sub[0]).getInt());
  }
  for (auto &&[i, t] : llvm::enumerate(inputTypes)) {
    if (!dependentParamPositions.contains(static_cast<int64_t>(i)))
      continue;
    parameterTypes.push_back(t);
  }

  auto checkAuxRegion = [&](Region &region, StringRef name) -> LogicalResult {
    if (region.empty())
      return success();

    if (region.getNumArguments() != parameterTypes.size()) {
      return op.emitOpError()
             << "expects the '" << name
             << "' region to have as many arguments as "
                "bound dependent type parameters, got "
             << region.getNumArguments() << " vs " << parameterTypes.size();
    }

    for (auto &&[i, left, right] :
         llvm::enumerate(region.getArgumentTypes(), parameterTypes)) {
      if (left == right)
        continue;
      return op.emitOpError()
             << "expects '" << name
             << "' region argument types to match the bound "
                "dependent type parameters in order, mismatch at position "
             << i << ", " << left << " vs " << right;
    }

    auto yield = dyn_cast<DepYieldOp>(region.front().getTerminator());
    if (!yield)
      return op.emitOpError()
             << "expects '" << name
             << "' region blocks to be terminated with dep.yield";
    if (yield->getNumOperands() != 1 ||
        !yield->getOperand(0).getType().isInteger(1))
      return op.emitOpError() << "expects '" << name
                              << "' region blocks to yield a single i1 value";

    WalkResult walkResult = region.walk([](Operation *op) {
      if (!isPure(op))
        return WalkResult::interrupt();
      // If the op is known to have recursive effects, no need to enter it.
      if (op->hasTrait<OpTrait::HasRecursiveMemoryEffects>())
        return WalkResult::skip();
      return WalkResult::advance();
    });

    return success(!walkResult.wasInterrupted());
  };
  if (failed(checkAuxRegion(op.getRequires(), "requires")))
    return failure();
  return checkAuxRegion(op.getEnsures(), "ensures");
}

// Verify that types of `dep.yield` operands terminating any block in the region
// match `expectedTypes`. Emit an error message based on `expectedDescription`
// otherwise.
static LogicalResult verifyYieldedValueTypes(Region &body,
                                             TypeRange expectedTypes,
                                             StringRef expectedDescription) {
  for (Block &block : body.getBlocks()) {
    auto yield = dyn_cast<DepYieldOp>(block.getTerminator());
    if (!yield)
      continue;
    if (yield.getNumOperands() != expectedTypes.size()) {
      return yield.emitOpError()
             << "expects the number of yielded values to match "
             << expectedDescription << ", got " << yield.getNumOperands()
             << " vs " << expectedTypes.size();
    }
    for (auto &&[i, left, right] :
         llvm::enumerate(yield.getOperandTypes(), expectedTypes)) {
      if (left == right)
        continue;
      return yield.emitOpError()
             << "expects yielded value types to match " << expectedDescription
             << ", mismatch at position " << i << ", " << left << " vs "
             << right;
    }
  }
  return success();
}

// Parses a `binds` clause of a binder operation:
//
//   binds ::= `binds` `{` bind-list `}`
//   bind-list ::= *comma separated list of* (ssa-value `->` attr)
//
// Uses `lookupBinding` to find the position to use in the `binds`
// attribute based on the parsed SSA name. Populates `result` with
// the `binds` attribute.
static ParseResult
parseBindsClause(OpAsmParser &parser, OperationState &result,
                 function_ref<std::optional<int64_t>(StringRef)> lookupBinding,
                 StringRef bindableDescription) {
  SmallVector<OpAsmParser::UnresolvedOperand> boundValues;
  SmallVector<Attribute> boundParams;
  auto parseBinding = [&]() -> ParseResult {
    if (parser.parseOperand(boundValues.emplace_back(),
                            /*allowResultNumber=*/false) ||
        parser.parseArrow() ||
        parser.parseAttribute(boundParams.emplace_back()))
      return failure();
    return success();
  };
  if (parser.parseKeyword("binds") ||
      parser.parseCommaSeparatedList(OpAsmParser::Delimiter::Braces,
                                     parseBinding))
    return failure();

  Builder builder = parser.getBuilder();
  SmallVector<Attribute> binds;
  binds.reserve(boundParams.size());
  for (auto &&[boundValue, boundParam] : llvm::zip(boundValues, boundParams)) {
    std::optional<int64_t> position = lookupBinding(boundValue.name);
    if (!position)
      return parser.emitError(boundValue.location)
             << "attempting to bind a value that is not "
             << bindableDescription;
    binds.push_back(builder.getArrayAttr(
        {builder.getI32IntegerAttr(*position), boundParam}));
  }
  result.addAttribute("binds", builder.getArrayAttr(binds));
  return success();
}

// Parses optional requires/ensures/body regions of a binder operation.
//
//   regions ::= (`requires` region)? (`ensures` region)? region?
//
// If `bodyArguments` are provided, uses those as arguments of the entry
// block of the body region.
static ParseResult
parseBinderRegions(OpAsmParser &parser, OperationState &result,
                   ArrayRef<OpAsmParser::Argument> bodyArguments = {}) {
  Region *
    requires
  = result.addRegion();
  if (succeeded(parser.parseOptionalKeyword("requires")) &&
      failed(parser.parseRegion(*requires)))
    return failure();

  Region *ensures = result.addRegion();
  if (succeeded(parser.parseOptionalKeyword("ensures")) &&
      failed(parser.parseRegion(*ensures)))
    return failure();

  Region *body = result.addRegion();
  OptionalParseResult bodyParseResult =
      parser.parseOptionalRegion(*body, bodyArguments);
  if (bodyParseResult.has_value() && failed(*bodyParseResult))
    return failure();
  return success();
}

template <typename Range, typename PrintBinding>
static void printBindsClause(OpAsmPrinter &printer, const Range &bindings,
                             PrintBinding printBinding) {
  printer.printNewline();
  printer << "binds {";
  printer.printNewline();
  printer.increaseIndent();
  bool printedOne = false;
  llvm::interleave(
      bindings,
      [&](const auto &binding) {
        printBinding(binding);
        printedOne = true;
      },
      [&] {
        printer << ',';
        printer.printNewline();
      });
  if (printedOne)
    printer.printNewline();
  printer.decreaseIndent();
  printer << '}';
  printer.printNewline();
}

static void printBinderAuxRegions(OpAsmPrinter &printer, Region &requires,
                                  Region &ensures) {
  if (!requires.empty()) {
    printer << "requires ";
    printer.printRegion(requires);
    printer.printNewline();
  }
  if (!ensures.empty()) {
    printer << "ensures ";
    printer.printRegion(ensures);
    printer.printNewline();
  }
}

SmallVector<std::pair<Value, Attribute>> DepBindOp::getBindings() {
  SmallVector<std::pair<Value, Attribute>> result;
  for (auto binding : getBinds().getAsValueRange<ArrayAttr>()) {
    int64_t position = cast<IntegerAttr>(binding[0]).getInt();
    result.emplace_back(getOperand(position), binding[1]);
  }
  return result;
}

LogicalResult DepBindOp::verify() {
  if (failed(verifyDepBinderOp(*this)))
    return failure();
  if (failed(verifyYieldedValueTypes(getBody(), getResultTypes(),
                                     "dep.bind result types")))
    return failure();
  return verifyDepBinderAuxRegions(*this, getOperandTypes());
}

ParseResult DepBindOp::parse(OpAsmParser &parser, OperationState &result) {
  SmallVector<OpAsmParser::UnresolvedOperand> operands;
  SmallVector<Type> operandTypes;
  auto parseOperandAndType = [&]() -> ParseResult {
    if (parser.parseOperand(operands.emplace_back(),
                            /*allowResultNumber=*/false) ||
        parser.parseColonType(operandTypes.emplace_back()))
      return failure();
    return success();
  };
  if (parser.parseCommaSeparatedList(OpAsmParser::Delimiter::Paren,
                                     parseOperandAndType))
    return failure();

  SmallVector<Type> resultTypes;
  if (parser.parseOptionalArrowTypeList(resultTypes))
    return failure();
  result.addTypes(resultTypes);

  if (failed(parser.parseOptionalAttrDictWithKeyword(result.attributes)))
    return failure();

  if (failed(parseBindsClause(
          parser, result,
          [&](StringRef name) -> std::optional<int64_t> {
            for (auto &&[i, operand] : llvm::enumerate(operands))
              if (name == operand.name)
                return i;
            return std::nullopt;
          },
          "an operand")))
    return failure();

  if (parser.resolveOperands(operands, operandTypes,
                             parser.getCurrentLocation(), result.operands))
    return failure();

  return parseBinderRegions(parser, result);
}

void DepBindOp::print(OpAsmPrinter &printer) {
  printer << " (";
  llvm::interleaveComma(llvm::zip(getOperands(), getOperandTypes()),
                        printer.getStream(),
                        [&](std::tuple<Value, Type> operandAndType) {
                          auto &&[operand, type] = operandAndType;
                          printer.printOperand(operand);
                          printer << ": ";
                          printer.printType(type);
                        });
  printer << ')';
  printer.printArrowTypeList(getResultTypes());

  printer.printNewline();
  printer.printOptionalAttrDictWithKeyword(getOperation()->getAttrs(),
                                           {getBindsAttrName().getValue()});

  auto bindings = getBindings();
  printBindsClause(printer, bindings,
                   [&](const std::pair<Value, Attribute> &bind) {
                     auto &&[value, param] = bind;
                     printer.printOperand(value);
                     printer << " -> " << param;
                   });
  printBinderAuxRegions(printer, getRequires(), getEnsures());
  if (!getBody().empty())
    printer.printRegion(getBody());
}

SmallVector<std::pair<Value, Attribute>> DepFuncOp::getBindings() {
  if (getBody().empty())
    return {};

  SmallVector<std::pair<Value, Attribute>> result;
  for (auto binding : getBinds().getAsValueRange<ArrayAttr>()) {
    int64_t position = cast<IntegerAttr>(binding[0]).getInt();
    Value value = getBody().front().getArgument(position);
    result.emplace_back(value, binding[1]);
  }
  return result;
}

LogicalResult DepFuncOp::verify() {
  if (failed(verifyDepBinderOp(*this)))
    return failure();

  if (!getBody().empty()) {
    if (getBody().getNumArguments() != getFunctionType().getNumInputs()) {
      return emitOpError()
             << "expects the 'body' region to have the same number "
                "of arguments as the function signature";
    }
    for (auto &&[i, left, right] : llvm::enumerate(
             getBody().getArgumentTypes(), getFunctionType().getInputs())) {
      if (left == right)
        continue;
      return emitOpError()
             << "expects 'body' region argument types to match function "
                "signature, mismatch at position "
             << i << ", " << left << " vs " << right;
    }

    if (failed(verifyYieldedValueTypes(
            getBody(), getFunctionType().getResults(), "function signature")))
      return failure();
  }

  return verifyDepBinderAuxRegions(*this, getFunctionType().getInputs());
}

ParseResult DepFuncOp::parse(OpAsmParser &parser, OperationState &result) {
  Builder builder = parser.getBuilder();
  StringRef keyword;
  if (succeeded(parser.parseOptionalKeyword(&keyword))) {
    result.addAttribute("sym_visibility", builder.getStringAttr(keyword));
  }

  StringAttr symbolName;
  if (failed(parser.parseSymbolName(symbolName, "sym_name", result.attributes)))
    return failure();

  SmallVector<Type> resultTypes;
  SmallVector<OpAsmParser::Argument> bodyArguments;
  if (parser.parseArgumentList(bodyArguments, OpAsmParser::Delimiter::Paren,
                               /*allowType=*/true, /*allowAttrs=*/false) ||
      parser.parseOptionalArrowTypeList(resultTypes))
    return failure();

  SmallVector<Type> inputTypes = llvm::map_to_vector(
      bodyArguments, [](OpAsmParser::Argument &arg) { return arg.type; });

  result.addAttribute("function_type", TypeAttr::get(builder.getFunctionType(
                                           inputTypes, resultTypes)));

  if (failed(parser.parseOptionalAttrDictWithKeyword(result.attributes)))
    return failure();

  if (failed(parseBindsClause(
          parser, result,
          [&](StringRef name) -> std::optional<int64_t> {
            for (auto &&[i, argument] : llvm::enumerate(bodyArguments))
              if (name == argument.ssaName.name)
                return i;
            return std::nullopt;
          },
          "a function argument")))
    return failure();

  return parseBinderRegions(parser, result, bodyArguments);
}

void DepFuncOp::print(OpAsmPrinter &printer) {
  printer << ' ';
  if (std::optional<StringRef> visibility = getSymVisibility()) {
    printer.printKeywordOrString(*visibility);
    printer << ' ';
  }

  printer.printSymbolName(getSymName());
  printer << '(';
  if (!getBody().empty()) {
    llvm::interleaveComma(
        getBody().getArguments(), printer.getStream(),
        [&](BlockArgument arg) { printer.printRegionArgument(arg); });
  } else {
    llvm::interleaveComma(llvm::enumerate(getFunctionType().getInputs()),
                          printer.getStream(), [&](auto input) {
                            printer << "%arg" << input.index() << ": ";
                            printer.printType(input.value());
                          });
  }
  printer << ')';
  printer.printArrowTypeList(getFunctionType().getResults());

  printer.printNewline();
  printer.printOptionalAttrDictWithKeyword(
      getOperation()->getAttrs(),
      {getSymNameAttrName().getValue(), getSymVisibilityAttrName().getValue(),
       getFunctionTypeAttrName().getValue(), getBindsAttrName().getValue()});

  if (!getBody().empty()) {
    auto bindings = getBindings();
    printBindsClause(printer, bindings,
                     [&](const std::pair<Value, Attribute> &bind) {
                       auto &&[value, param] = bind;
                       printer.printOperand(value);
                       printer << " -> " << param;
                     });
  } else {
    printBindsClause(printer, getBinds(), [&](const Attribute &bind) {
      ArrayAttr binding = cast<ArrayAttr>(bind);
      printer << "%arg" << cast<IntegerAttr>(binding[0]).getInt();
      printer << " -> " << binding[1];
    });
  }
  printBinderAuxRegions(printer, getRequires(), getEnsures());
  if (!getBody().empty()) {
    printer.printRegion(getBody(), /*printEntryBlockArgs=*/false);
  }
}
