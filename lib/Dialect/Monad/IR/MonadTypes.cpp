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

/// Parses a possibly empty set of errors in braces, in any order, rejects
/// duplicates, and sorts the errors by name.
static ParseResult parseErrorSet(AsmParser &parser,
                                 SmallVector<ErrorAttr> &errors) {
  if (parser.parseCommaSeparatedList(
          AsmParser::Delimiter::Braces, [&]() -> ParseResult {
            SMLoc loc = parser.getCurrentLocation();
            Attribute attr;
            if (parser.parseAttribute(attr))
              return failure();
            auto error = dyn_cast<ErrorAttr>(attr);
            if (!error)
              return parser.emitError(loc) << "expected an error, got " << attr;
            if (llvm::is_contained(errors, error))
              return parser.emitError(loc)
                     << "expected distinct errors, got " << error << " twice";
            errors.push_back(error);
            return success();
          }))
    return failure();
  llvm::sort(errors, [](ErrorAttr lhs, ErrorAttr rhs) {
    return lhs.getName() < rhs.getName();
  });
  return success();
}

/// Prints a set of errors in braces.
static void printErrorSet(AsmPrinter &printer, ArrayRef<ErrorAttr> errors) {
  printer << "{";
  llvm::interleaveComma(
      errors, printer, [&](ErrorAttr error) { printer.printAttribute(error); });
  printer << "}";
}

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/Monad/IR/MonadOpsTypes.cpp.inc"

//===----------------------------------------------------------------------===//
// MaybeType
//===----------------------------------------------------------------------===//

/// Returns the maybe type with the given value types.
MonadTypeInterface MaybeType::cloneWithValueTypes(TypeRange valueTypes) const {
  return MaybeType::get(getContext(), llvm::to_vector(valueTypes));
}

//===----------------------------------------------------------------------===//
// EitherType
//===----------------------------------------------------------------------===//

/// Verifies that the errors are sorted by name and distinct.
LogicalResult EitherType::verify(function_ref<InFlightDiagnostic()> emitError,
                                 ArrayRef<Type> valueTypes,
                                 ArrayRef<ErrorAttr> errors) {
  for (size_t index = 1, size = errors.size(); index < size; ++index)
    if (errors[index - 1].getName() >= errors[index].getName())
      return emitError()
             << "expects the errors to be sorted by name and distinct, got "
             << errors[index - 1] << " before " << errors[index];
  return success();
}

/// Returns the either type with the given value types and the errors of this
/// type.
MonadTypeInterface EitherType::cloneWithValueTypes(TypeRange valueTypes) const {
  return EitherType::get(getContext(), llvm::to_vector(valueTypes),
                         getErrors());
}

void MonadDialect::registerTypes() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "fum/Dialect/Monad/IR/MonadOpsTypes.cpp.inc"
      >();
}
