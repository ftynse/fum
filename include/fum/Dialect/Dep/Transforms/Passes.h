//===- DepPasses.h - Dep dialect passes -------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef DEP_DEPPASSES_H
#define DEP_DEPPASSES_H

#include "fum/Dialect/Dep/IR/DepDialect.h"
#include "fum/Dialect/Dep/IR/DepOps.h"
#include "mlir/Pass/Pass.h"
#include <memory>

namespace mlir {
namespace arith {
class ArithDialect;
}
namespace func {
class FuncDialect;
}

namespace dep {
#define GEN_PASS_DECL
#include "fum/Dialect/Dep/Transforms/Passes.h.inc"

#define GEN_PASS_REGISTRATION
#include "fum/Dialect/Dep/Transforms/Passes.h.inc"
} // namespace dep
} // namespace mlir

#endif
