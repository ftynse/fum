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
#include "llvm/ADT/DenseSet.h"
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

// Verify that a region contains only operations with no side effects.
static LogicalResult verifyPureRegion(Operation *op, Region &region,
                                      StringRef regionName) {
  WalkResult walkResult = region.walk([](Operation *op) {
    if (!isPure(op))
      return WalkResult::interrupt();
    if (op->hasTrait<OpTrait::HasRecursiveMemoryEffects>())
      return WalkResult::skip();
    return WalkResult::advance();
  });
  if (walkResult.wasInterrupted())
    return op->emitOpError() << "expects '" << regionName
                             << "' region to contain only pure operations";
  return success();
}

// Verify one auxiliary region of a binder operation. `inputTypes` contains
// the types of values that may be bound, in order.
template <typename OpTy>
static LogicalResult verifyDepBinderAuxRegion(OpTy op, Region &region,
                                              TypeRange inputTypes,
                                              StringRef name) {
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

  return verifyPureRegion(op.getOperation(), region, name);
}

template <typename OpTy>
static LogicalResult verifyDepBinderAuxRegions(OpTy op, TypeRange inputTypes) {
  if (failed(verifyDepBinderAuxRegion(op, op.getRequires(), inputTypes,
                                      "requires")))
    return failure();
  return verifyDepBinderAuxRegion(op, op.getEnsures(), inputTypes, "ensures");
}

// Verify that types of `dep.yield` operands terminating any block in the region
// match `expectedTypes`. Emit an error message based on `expectedDescription`
// otherwise.
static LogicalResult verifyYieldedValueTypes(Region &body,
                                             TypeRange expectedTypes,
                                             StringRef expectedDescription) {
  for (Block &block : body.getBlocks()) {
    DepYieldOp yield = dyn_cast<DepYieldOp>(block.getTerminator());
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

ParseResult DepTypeConstructorOp::parse(OpAsmParser &parser,
                                        OperationState &result) {
  Builder builder = parser.getBuilder();
  StringRef visibility;
  if (succeeded(parser.parseOptionalKeyword(&visibility)))
    result.addAttribute("sym_visibility", builder.getStringAttr(visibility));

  StringAttr symbolName;
  if (parser.parseSymbolName(symbolName, "sym_name", result.attributes))
    return failure();

  SmallVector<OpAsmParser::Argument> arguments;
  if (parser.parseArgumentList(arguments, OpAsmParser::Delimiter::Paren,
                               /*allowType=*/true,
                               /*allowAttrs=*/false))
    return failure();

  SmallVector<Attribute> inputTypes = llvm::map_to_vector(
      arguments, [&](OpAsmParser::Argument &argument) -> Attribute {
        return TypeAttr::get(argument.type);
      });
  result.addAttribute("input_types", builder.getArrayAttr(inputTypes));

  if (parser.parseOptionalAttrDictWithKeyword(result.attributes))
    return failure();

  if (failed(parseBindsClause(
          parser, result,
          [&](StringRef name) -> std::optional<int64_t> {
            for (auto &&[i, argument] : llvm::enumerate(arguments))
              if (name == argument.ssaName.name)
                return i;
            return std::nullopt;
          },
          "a type constructor argument")))
    return failure();

  Region *
    requires
  = result.addRegion();
  if (succeeded(parser.parseOptionalKeyword("requires")) &&
      parser.parseRegion(*requires))
    return failure();

  Region *body = result.addRegion();
  if (parser.parseRegion(*body, arguments))
    return failure();
  return success();
}

void DepTypeConstructorOp::print(OpAsmPrinter &printer) {
  printer << ' ';
  if (std::optional<StringRef> visibility = getSymVisibility()) {
    printer.printKeywordOrString(*visibility);
    printer << ' ';
  }
  printer.printSymbolName(getSymName());
  printer << '(';
  llvm::interleaveComma(
      getBody().front().getArguments(), printer.getStream(),
      [&](BlockArgument argument) { printer.printRegionArgument(argument); });
  printer << ')';

  printer.printOptionalAttrDictWithKeyword(
      getOperation()->getAttrs(),
      {getSymNameAttrName().getValue(), getSymVisibilityAttrName().getValue(),
       getInputTypesAttrName().getValue(), getBindsAttrName().getValue()});

  printBindsClause(printer, getBinds(), [&](const Attribute &binding) {
    ArrayAttr pair = cast<ArrayAttr>(binding);
    int64_t position = cast<IntegerAttr>(pair[0]).getInt();
    printer.printOperand(getBody().front().getArgument(position));
    printer << " -> " << pair[1];
  });
  if (!getRequires().empty()) {
    printer << "requires ";
    printer.printRegion(getRequires());
    printer.printNewline();
  }
  printer.printRegion(getBody(), /*printEntryBlockArgs=*/false);
}

LogicalResult DepTypeConstructorOp::verify() {
  if (failed(verifyDepBinderOp(*this)))
    return failure();

  SmallVector<Type> inputTypes =
      llvm::map_to_vector(getInputTypes(), [](Attribute attribute) {
        return cast<TypeAttr>(attribute).getValue();
      });
  auto verifyArguments = [&](Region &region,
                             StringRef regionName) -> LogicalResult {
    if (region.getNumArguments() != inputTypes.size())
      return emitOpError()
             << "expects the '" << regionName
             << "' region to have the same number of arguments as the type "
                "constructor signature, got "
             << region.getNumArguments() << " vs " << inputTypes.size();
    for (auto &&[i, left, right] :
         llvm::enumerate(region.getArgumentTypes(), inputTypes)) {
      if (left != right)
        return emitOpError()
               << "expects '" << regionName
               << "' region argument types to match the type constructor "
                  "signature, mismatch at position "
               << i << ", " << left << " vs " << right;
    }
    return success();
  };

  if (failed(verifyArguments(getBody(), "body")))
    return failure();
  if (failed(verifyDepBinderAuxRegion(*this, getRequires(), inputTypes,
                                      "requires")))
    return failure();

  for (Block &block : getBody()) {
    DepYieldOp yield = dyn_cast<DepYieldOp>(block.getTerminator());
    if (!yield)
      return emitOpError()
             << "expects the 'body' region to be terminated with dep.yield";
    if (yield.getNumOperands() != 1 ||
        yield.getOperand(0).getType() != DependentTypeType::get(getContext()))
      return emitOpError()
             << "expects the 'body' region to yield a single !dep.type value";
  }
  return verifyPureRegion(getOperation(), getBody(), "body");
}

SmallVector<std::pair<Value, Attribute>> DepTypeConstructorOp::getBindings() {
  SmallVector<std::pair<Value, Attribute>> result;
  for (Attribute binding : getBinds().getValue()) {
    ArrayAttr pair = cast<ArrayAttr>(binding);
    int64_t position = cast<IntegerAttr>(pair[0]).getInt();
    result.emplace_back(getBody().front().getArgument(position), pair[1]);
  }
  return result;
}

static LogicalResult verifyInsideTypeConstructor(Operation *op) {
  if (!op->getParentOfType<DepTypeConstructorOp>())
    return op->emitOpError()
           << "must appear inside a dep.type.constructor operation";
  return success();
}

LogicalResult DepTypeOp::verify() {
  return verifyInsideTypeConstructor(getOperation());
}

/// Parses the subtypes of a type sum or product: either `{ "name": %type, ...
/// }` or `%type, ...`, followed by an optional attribute dictionary.
static ParseResult parseSubtypes(OpAsmParser &parser, OperationState &result) {
  SmallVector<OpAsmParser::UnresolvedOperand> operands;
  SmallVector<StringRef> names;

  auto parseNamedElement = [&]() -> ParseResult {
    std::string name;
    if (parser.parseString(&name) || parser.parseColon() ||
        parser.parseOperand(operands.emplace_back()))
      return failure();
    names.push_back(parser.getBuilder().getStringAttr(name).getValue());
    return success();
  };

  auto parseUnnamedElement = [&]() -> ParseResult {
    if (parser.parseOperand(operands.emplace_back()))
      return failure();
    return success();
  };

  if (succeeded(parser.parseOptionalLBrace())) {
    if (parser.parseCommaSeparatedList(OpAsmParser::Delimiter::None,
                                       parseNamedElement) ||
        parser.parseRBrace())
      return failure();
  } else if (parser.parseCommaSeparatedList(OpAsmParser::Delimiter::None,
                                            parseUnnamedElement)) {
    return failure();
  }

  Type elementType = DependentTypeType::get(parser.getContext());
  result.addTypes(elementType);
  if (!names.empty())
    result.addAttribute("names", parser.getBuilder().getStrArrayAttr(names));

  if (parser.resolveOperands(operands, elementType, parser.getCurrentLocation(),
                             result.operands))
    return failure();
  return parser.parseOptionalAttrDictWithKeyword(result.attributes);
}

/// Prints the subtypes of a type sum or product in the form parsed by
/// `parseSubtypes`.
static void printSubtypes(OpAsmPrinter &printer, Operation *op) {
  ArrayAttr names = op->getAttrOfType<ArrayAttr>("names");
  if (names) {
    printer << " {";
    printer.increaseIndent();
    printer.printNewline();
    llvm::interleave(
        llvm::enumerate(op->getOperands()),
        [&](auto element) {
          printer << names[element.index()] << ": ";
          printer.printOperand(element.value());
        },
        [&] {
          printer << ',';
          printer.printNewline();
        });
    printer.decreaseIndent();
    printer.printNewline();
    printer << '}';
  } else {
    printer << ' ';
    llvm::interleaveComma(
        op->getOperands(), printer.getStream(),
        [&](Value operand) { printer.printOperand(operand); });
  }
  printer.printOptionalAttrDictWithKeyword(op->getAttrs(), {"names"});
}

/// Verifies that `names`, if present, has one entry per subtype.
static LogicalResult verifySubtypeNames(Operation *op, ArrayAttr names,
                                        size_t subtypeCount) {
  if (names && names.size() != subtypeCount)
    return op->emitOpError() << "expects 'names' to have " << subtypeCount
                             << " entries, but got " << names.size();
  return success();
}

ParseResult DepTypeSumOp::parse(OpAsmParser &parser, OperationState &result) {
  return parseSubtypes(parser, result);
}

void DepTypeSumOp::print(OpAsmPrinter &printer) {
  printSubtypes(printer, getOperation());
}

ParseResult DepTypeProductOp::parse(OpAsmParser &parser,
                                    OperationState &result) {
  return parseSubtypes(parser, result);
}

void DepTypeProductOp::print(OpAsmPrinter &printer) {
  printSubtypes(printer, getOperation());
}

LogicalResult DepTypeProductOp::verify() {
  if (failed(verifyInsideTypeConstructor(getOperation())))
    return failure();
  return verifySubtypeNames(getOperation(), getNamesAttr(),
                            getSubtypes().size());
}

/// Verifies that the sum is in a type constructor and that its case names, if
/// any, are distinct and one per subtype.
LogicalResult DepTypeSumOp::verify() {
  if (failed(verifyInsideTypeConstructor(getOperation())) ||
      failed(verifySubtypeNames(getOperation(), getNamesAttr(),
                                getSubtypes().size())))
    return failure();
  ArrayAttr names = getNamesAttr();
  if (!names)
    return success();
  llvm::SmallDenseSet<StringRef> seen;
  for (StringRef name : names.getAsValueRange<StringAttr>())
    if (!seen.insert(name).second)
      return emitOpError() << "expects distinct case names, got '" << name
                           << "' twice";
  return success();
}

//===----------------------------------------------------------------------===//
// DepSumMakeOp
//===----------------------------------------------------------------------===//

/// Parses `case-name ( `(` fields `)` )? attr-dict `:` sum-type`; the operand
/// types are the field types of the case.
ParseResult DepSumMakeOp::parse(OpAsmParser &parser, OperationState &result) {
  SMLoc loc = parser.getCurrentLocation();
  StringRef caseName;
  SmallVector<OpAsmParser::UnresolvedOperand> fields;
  SumType type;
  if (parser.parseKeyword(&caseName))
    return failure();
  if (succeeded(parser.parseOptionalLParen()) &&
      (parser.parseOperandList(fields) || parser.parseRParen()))
    return failure();
  if (parser.parseOptionalAttrDict(result.attributes) || parser.parseColon() ||
      parser.parseType(type))
    return failure();
  std::optional<SmallVector<Type>> fieldTypes = type.getCaseFields(caseName);
  if (!fieldTypes)
    return parser.emitError(loc)
           << "expects '" << caseName << "' to be a case of " << type;
  if (parser.resolveOperands(fields, *fieldTypes, loc, result.operands))
    return failure();
  result.addAttribute(getCaseNameAttrName(result.name),
                      parser.getBuilder().getStringAttr(caseName));
  result.addTypes(type);
  return success();
}

void DepSumMakeOp::print(OpAsmPrinter &printer) {
  printer << ' ' << getCaseName();
  if (!getFields().empty())
    printer << '(' << getFields() << ')';
  printer.printOptionalAttrDict((*this)->getAttrs(), {getCaseNameAttrName()});
  printer << " : " << getType();
}

/// Verifies that the case exists and that the operands are its fields.
LogicalResult DepSumMakeOp::verify() {
  std::optional<SmallVector<Type>> fieldTypes =
      getType().getCaseFields(getCaseName());
  if (!fieldTypes)
    return emitOpError() << "expects '" << getCaseName() << "' to be a case of "
                         << getType();
  if (TypeRange(getFields().getTypes()) != TypeRange(*fieldTypes))
    return emitOpError() << "expects the fields of case '" << getCaseName()
                         << "' to have types (" << *fieldTypes << ")";
  return success();
}

//===----------------------------------------------------------------------===//
// DepSumSwitchOp
//===----------------------------------------------------------------------===//

/// Parses `%input : sum-type, [ (default: ^dest ,)? case: ^dest, ... ]`.
ParseResult DepSumSwitchOp::parse(OpAsmParser &parser, OperationState &result) {
  OpAsmParser::UnresolvedOperand input;
  SumType inputType;
  SmallVector<Attribute> names;
  SmallVector<Block *> destinations;
  Block *defaultDestination = nullptr;
  auto parseCase = [&]() -> ParseResult {
    SMLoc loc = parser.getCurrentLocation();
    StringRef name;
    Block *destination;
    if (parser.parseKeyword(&name) || parser.parseColon() ||
        parser.parseSuccessor(destination))
      return failure();
    if (name != "default") {
      names.push_back(parser.getBuilder().getStringAttr(name));
      destinations.push_back(destination);
    } else if (names.empty() && !defaultDestination) {
      defaultDestination = destination;
    } else {
      return parser.emitError(loc, "expected the default case first");
    }
    return success();
  };
  if (parser.parseOperand(input) || parser.parseColon() ||
      parser.parseType(inputType) ||
      parser.resolveOperand(input, inputType, result.operands) ||
      parser.parseComma() ||
      parser.parseCommaSeparatedList(OpAsmParser::Delimiter::Square,
                                     parseCase) ||
      parser.parseOptionalAttrDict(result.attributes))
    return failure();
  if (defaultDestination)
    destinations.push_back(defaultDestination);
  result.addAttribute(getCaseNamesAttrName(result.name),
                      parser.getBuilder().getArrayAttr(names));
  result.addSuccessors(destinations);
  return success();
}

void DepSumSwitchOp::print(OpAsmPrinter &printer) {
  printer << ' ' << getInput() << " : " << getInput().getType() << ", [";
  printer.increaseIndent();
  auto printCase = [&](StringRef name, Block *destination, bool last) {
    printer.printNewline();
    printer << name << ": ";
    printer.printSuccessor(destination);
    if (!last)
      printer << ',';
  };
  size_t count = getCaseNames().size();
  if (Block *defaultDestination = getDefaultDestination())
    printCase("default", defaultDestination, count == 0);
  for (auto [index, name] :
       llvm::enumerate(getCaseNames().getAsValueRange<StringAttr>()))
    printCase(name, getDestinations()[index], index + 1 == count);
  printer.decreaseIndent();
  printer.printNewline();
  printer << ']';
  printer.printOptionalAttrDict((*this)->getAttrs(), {getCaseNamesAttrName()});
}

Block *DepSumSwitchOp::getDefaultDestination() {
  if (getDestinations().size() == getCaseNames().size())
    return nullptr;
  return getDestinations().back();
}

/// Verifies that every case is listed once, or handled by `default`, and that
/// each successor takes the fields of its case.
LogicalResult DepSumSwitchOp::verify() {
  SumType inputType = getInput().getType();
  size_t count = getCaseNames().size();
  if (getDestinations().size() != count &&
      getDestinations().size() != count + 1)
    return emitOpError() << "expects one successor per case and at most one "
                            "default successor";
  llvm::SmallDenseSet<StringRef> listed;
  for (auto [index, name] :
       llvm::enumerate(getCaseNames().getAsValueRange<StringAttr>())) {
    std::optional<SmallVector<Type>> fieldTypes = inputType.getCaseFields(name);
    if (!fieldTypes)
      return emitOpError() << "expects '" << name << "' to be a case of "
                           << inputType;
    if (!listed.insert(name).second)
      return emitOpError() << "expects case '" << name << "' to be listed once";
    if (getDestinations()[index]->getArgumentTypes() != TypeRange(*fieldTypes))
      return emitOpError() << "expects the successor of case '" << name
                           << "' to take arguments of types (" << *fieldTypes
                           << ")";
  }
  bool exhaustive = listed.size() == inputType.getCases().size();
  if (!getDefaultDestination() && !exhaustive)
    return emitOpError() << "expects every case to be listed, or a default "
                            "case";
  if (getDefaultDestination() && exhaustive)
    return emitOpError() << "expects the default case to handle at least one "
                            "case";
  return success();
}

/// The switch produces every argument of the successor and forwards no
/// operands.
SuccessorOperands DepSumSwitchOp::getSuccessorOperands(unsigned index) {
  return SuccessorOperands(getDestinations()[index]->getNumArguments(),
                           MutableOperandRange(getOperation(), 1, 0));
}
