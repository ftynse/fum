//===- ADTTypes.h - ADT dialect types ---------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef FUM_DIALECT_ADT_IR_ADTTYPES_H
#define FUM_DIALECT_ADT_IR_ADTTYPES_H

#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"

#include <optional>

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/ADT/IR/ADTOpsTypes.h.inc"

#endif // FUM_DIALECT_ADT_IR_ADTTYPES_H
