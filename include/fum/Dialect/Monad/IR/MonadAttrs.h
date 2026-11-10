//===- MonadAttrs.h - Monad dialect attributes ------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef FUM_DIALECT_MONAD_IR_MONADATTRS_H
#define FUM_DIALECT_MONAD_IR_MONADATTRS_H

#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinAttributes.h"

#define GET_ATTRDEF_CLASSES
#include "fum/Dialect/Monad/IR/MonadAttrs.h.inc"

#endif // FUM_DIALECT_MONAD_IR_MONADATTRS_H
