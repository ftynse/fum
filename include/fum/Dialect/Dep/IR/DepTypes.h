//===- DepTypes.h - Dep dialect types ---------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef DEP_DEPTYPES_H
#define DEP_DEPTYPES_H

#include "fum/Dialect/Dep/Interfaces/DepTypeInteraces.h"
#include "mlir/IR/BuiltinTypes.h"

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/Dep/IR/DepTypes.h.inc"

#endif // DEP_DEPTYPES_H
