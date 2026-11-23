//===- MonadTypes.cpp - Monad dialect types ---------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Monad/IR/MonadTypes.h"

#include "fum/Dialect/Monad/IR/MonadDialect.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "llvm/ADT/TypeSwitch.h"

using namespace mlir;
using namespace mlir::monad;

/// Parses a possibly empty comma-separated list of value types.
static ParseResult parseValueTypes(AsmParser &parser,
                                   SmallVector<Type> &valueTypes) {
  Type type;
  OptionalParseResult first = parser.parseOptionalType(type);
  if (!first.has_value())
    return success();
  if (failed(*first))
    return failure();
  valueTypes.push_back(type);
  while (succeeded(parser.parseOptionalComma())) {
    if (parser.parseType(type))
      return failure();
    valueTypes.push_back(type);
  }
  return success();
}

/// Prints a comma-separated list of value types.
static void printValueTypes(AsmPrinter &printer, ArrayRef<Type> valueTypes) {
  llvm::interleaveComma(valueTypes, printer);
}

/// Parses the right types of an either type, where `none` alone stands for
/// no types.
static ParseResult parseRightTypes(AsmParser &parser,
                                   SmallVector<Type> &valueTypes) {
  SMLoc loc = parser.getCurrentLocation();
  if (parser.parseCommaSeparatedList(
          [&]() { return parser.parseType(valueTypes.emplace_back()); }))
    return failure();
  if (valueTypes.size() == 1 && isa<NoneType>(valueTypes.front())) {
    valueTypes.clear();
    return success();
  }
  if (llvm::any_of(valueTypes, llvm::IsaPred<NoneType>))
    return parser.emitError(loc)
           << "expects 'none' to be the only right type of an either type";
  return success();
}

/// Prints the right types of an either type, or `none` if there are none.
static void printRightTypes(AsmPrinter &printer, ArrayRef<Type> valueTypes) {
  if (valueTypes.empty()) {
    printer << "none";
    return;
  }
  llvm::interleaveComma(valueTypes, printer);
}

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/Monad/IR/MonadOpsTypes.cpp.inc"

/// Returns this type with the given value types.
MonadTypeInterface MaybeType::cloneWithValueTypes(TypeRange valueTypes) const {
  return MaybeType::get(getContext(), llvm::to_vector(valueTypes));
}

/// Returns this type with the given value types.
MonadTypeInterface EitherType::cloneWithValueTypes(TypeRange valueTypes) const {
  return EitherType::get(getContext(), getLeftType(),
                         llvm::to_vector(valueTypes));
}

/// Verifies that no value type is `none`.
LogicalResult EitherType::verify(function_ref<InFlightDiagnostic()> emitError,
                                 Type leftType, ArrayRef<Type> valueTypes) {
  if (llvm::any_of(valueTypes, llvm::IsaPred<NoneType>))
    return emitError() << "expects no 'none' value type; an either type "
                          "without value types is written with 'none'";
  return success();
}

void MonadDialect::registerTypes() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "fum/Dialect/Monad/IR/MonadOpsTypes.cpp.inc"
      >();
}
