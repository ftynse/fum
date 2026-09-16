//===- DepDialect.cpp - Dep dialect -----------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Dep/IR/DepDialect.h"
#include "fum/Dialect/Dep/IR/DepOps.h"
#include "fum/Dialect/Dep/IR/DepTypes.h"

using namespace mlir;
using namespace mlir::dep;

#include "fum/Dialect/Dep/IR/DepOpsDialect.cpp.inc"

//===----------------------------------------------------------------------===//
// Dep dialect.
//===----------------------------------------------------------------------===//

// Adds operations, attributes and types to the dialect object.
void DepDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "fum/Dialect/Dep/IR/DepOps.cpp.inc"
      >();
  registerTypes();
}
