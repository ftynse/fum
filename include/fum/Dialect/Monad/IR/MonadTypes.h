//===- MonadTypes.h - Monad dialect types -----------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef FUM_DIALECT_MONAD_IR_MONADTYPES_H
#define FUM_DIALECT_MONAD_IR_MONADTYPES_H

#include "fum/Dialect/Monad/Interfaces/MonadTypeInterfaces.h"
#include "mlir/IR/BuiltinTypes.h"

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/Monad/IR/MonadOpsTypes.h.inc"

#endif // FUM_DIALECT_MONAD_IR_MONADTYPES_H
