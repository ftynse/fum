//===- DepTypes.cpp - Dep dialect types -----------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Dep/IR/DepTypes.h"

#include "fum/Dialect/Dep/IR/DepDialect.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "llvm/ADT/TypeSwitch.h"

using namespace mlir::dep;

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/Dep/IR/DepTypes.cpp.inc"

void DepDialect::registerTypes() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "fum/Dialect/Dep/IR/DepTypes.cpp.inc"
      >();
}
