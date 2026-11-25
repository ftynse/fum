//===- ADTOps.cpp - ADT dialect ops -----------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/ADT/IR/ADTOps.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/OpImplementation.h"
#include "llvm/ADT/DenseSet.h"

using namespace mlir;
using namespace mlir::adt;

#define GET_OP_CLASSES
#include "fum/Dialect/ADT/IR/ADTOps.cpp.inc"

//===----------------------------------------------------------------------===//
// MakeOp
//===----------------------------------------------------------------------===//

/// Parses `case-name ( `(` fields `)` )? attr-dict `:` sum-type`; the operand
/// types are the field types of the case.
ParseResult MakeOp::parse(OpAsmParser &parser, OperationState &result) {
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

void MakeOp::print(OpAsmPrinter &printer) {
  printer << ' ' << getCaseName();
  if (!getFields().empty())
    printer << '(' << getFields() << ')';
  printer.printOptionalAttrDict((*this)->getAttrs(), {getCaseNameAttrName()});
  printer << " : " << getType();
}

/// Verifies that the case exists and that the operands are its fields.
LogicalResult MakeOp::verify() {
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
// SwitchOp
//===----------------------------------------------------------------------===//

/// Parses `%input : sum-type, [ (default: ^dest ,)? case: ^dest, ... ]`.
ParseResult SwitchOp::parse(OpAsmParser &parser, OperationState &result) {
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

void SwitchOp::print(OpAsmPrinter &printer) {
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

Block *SwitchOp::getDefaultDestination() {
  if (getDestinations().size() == getCaseNames().size())
    return nullptr;
  return getDestinations().back();
}

/// Verifies that every case is listed once, or handled by `default`, and that
/// each successor takes the fields of its case.
LogicalResult SwitchOp::verify() {
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
SuccessorOperands SwitchOp::getSuccessorOperands(unsigned index) {
  return SuccessorOperands(getDestinations()[index]->getNumArguments(),
                           MutableOperandRange(getOperation(), 1, 0));
}
