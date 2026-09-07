//===- DepOpInterfaces.h - Dependent Op Interfaces --------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef FUM_DIALECT_DEP_INTERFACES_DEPOPINTERFACES_H
#define FUM_DIALECT_DEP_INTERFACES_DEPOPINTERFACES_H

#include "mlir/IR/OpDefinition.h"

namespace mlir::dep {
// Uses `checkTypeSingle` on each type present inside the root operation, be
// operands, results, block arguments or attribute structures.
LogicalResult
verifyTypesInOps(function_ref<LogicalResult(Location, Type)> checkTypeSingle,
                 Operation *root);

// Verify usage of dependent types in binder operations, e.g., that all type
// parameters are bound at the use site.
LogicalResult verifyDependentTypeUsage(Operation *root);
} // namespace mlir::dep

#include "fum/Dialect/Dep/Interfaces/DepOpInterfaces.h.inc"

#endif // FUM_DIALECT_DEP_INTERFACES_DEPOpINTERFACES_H
