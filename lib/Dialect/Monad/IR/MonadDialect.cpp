//===- MonadDialect.cpp - Monad dialect -------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Monad/IR/MonadDialect.h"
#include "fum/Dialect/Monad/IR/MonadOps.h"
#include "fum/Dialect/Monad/IR/MonadTypes.h"

using namespace mlir;
using namespace mlir::monad;

#include "fum/Dialect/Monad/IR/MonadOpsDialect.cpp.inc"

/// Registers the operations and types of the dialect.
void MonadDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "fum/Dialect/Monad/IR/MonadOps.cpp.inc"
      >();
  registerTypes();
}
