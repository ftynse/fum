//===- ADTOps.h - ADT dialect ops -------------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef FUM_DIALECT_ADT_IR_ADTOPS_H
#define FUM_DIALECT_ADT_IR_ADTOPS_H

#include "mlir/Bytecode/BytecodeOpInterface.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/Interfaces/ControlFlowInterfaces.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

#include "fum/Dialect/ADT/IR/ADTDialect.h"
#include "fum/Dialect/ADT/IR/ADTTypes.h"

#define GET_OP_CLASSES
#include "fum/Dialect/ADT/IR/ADTOps.h.inc"

#endif // FUM_DIALECT_ADT_IR_ADTOPS_H
