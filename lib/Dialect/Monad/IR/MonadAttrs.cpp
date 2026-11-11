//===- MonadAttrs.cpp - Monad dialect attributes ----------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Monad/IR/MonadAttrs.h"

#include "fum/Dialect/Monad/IR/MonadDialect.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "llvm/ADT/TypeSwitch.h"

using namespace mlir;
using namespace mlir::monad;

#define GET_ATTRDEF_CLASSES
#include "fum/Dialect/Monad/IR/MonadAttrs.cpp.inc"

//===----------------------------------------------------------------------===//
// ErrorAttr
//===----------------------------------------------------------------------===//

/// Verifies that the error has a name.
LogicalResult ErrorAttr::verify(function_ref<InFlightDiagnostic()> emitError,
                                StringRef name) {
  if (name.empty())
    return emitError() << "expects a non-empty error name";
  return success();
}

void MonadDialect::registerAttributes() {
  addAttributes<
#define GET_ATTRDEF_LIST
#include "fum/Dialect/Monad/IR/MonadAttrs.cpp.inc"
      >();
}
