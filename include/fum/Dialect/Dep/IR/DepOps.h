//===- DepOps.h - Dep dialect ops -------------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef FUM_FUMOPS_H
#define FUM_FUMOPS_H

#include "mlir/Bytecode/BytecodeOpInterface.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/Interfaces/InferIntRangeInterface.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

#include "fum/Dialect/Dep/IR/DepTypes.h"
#include "fum/Dialect/Dep/Interfaces/DepOpInterfaces.h"

#define GET_OP_CLASSES
#include "fum/Dialect/Dep/IR/DepOps.h.inc"

#endif // FUM_FUMOPS_H
