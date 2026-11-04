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

void MonadDialect::registerTypes() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "fum/Dialect/Monad/IR/MonadOpsTypes.cpp.inc"
      >();
}
