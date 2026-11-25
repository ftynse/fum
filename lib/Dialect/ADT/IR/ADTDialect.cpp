//===- ADTDialect.cpp - ADT dialect -----------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/ADT/IR/ADTDialect.h"
#include "fum/Dialect/ADT/IR/ADTOps.h"

using namespace mlir;
using namespace mlir::adt;

#include "fum/Dialect/ADT/IR/ADTOpsDialect.cpp.inc"

void ADTDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "fum/Dialect/ADT/IR/ADTOps.cpp.inc"
      >();
  registerTypes();
}
