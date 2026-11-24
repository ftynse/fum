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

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/Monad/IR/MonadOpsTypes.cpp.inc"

/// Returns true if the enclosing type is a maybe type, and the arguments are
/// the value types of this type.
bool MaybeType::areBindTypesCompatible(Type enclosingType,
                                       TypeRange argumentTypes) const {
  return isa<MaybeType>(enclosingType) &&
         argumentTypes == TypeRange(getValueTypes());
}

/// Returns true if the enclosing type is an either type with the same left
/// type, and the arguments are the right types of this type.
bool EitherType::areBindTypesCompatible(Type enclosingType,
                                        TypeRange argumentTypes) const {
  auto enclosingEitherType = dyn_cast<EitherType>(enclosingType);
  return enclosingEitherType &&
         enclosingEitherType.getLeftType() == getLeftType() &&
         argumentTypes == TypeRange(getValueTypes());
}

/// Verifies that there is at least one right type.
LogicalResult EitherType::verify(function_ref<InFlightDiagnostic()> emitError,
                                 Type leftType, ArrayRef<Type> valueTypes) {
  if (valueTypes.empty())
    return emitError() << "expects at least one right type";
  return success();
}

void MonadDialect::registerTypes() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "fum/Dialect/Monad/IR/MonadOpsTypes.cpp.inc"
      >();
}
