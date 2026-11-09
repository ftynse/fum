//===- MonadOps.cpp - Monad dialect ops -------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Monad/IR/MonadOps.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/OpImplementation.h"

using namespace mlir;
using namespace mlir::monad;

#define GET_OP_CLASSES
#include "fum/Dialect/Monad/IR/MonadOps.cpp.inc"

//===----------------------------------------------------------------------===//
// MonadBindOp
//===----------------------------------------------------------------------===//

/// Verifies that the input is of the monad of the enclosing `monad.do` and
/// that the successor takes one argument of each value type of the input.
LogicalResult MonadBindOp::verify() {
  MonadTypeInterface inputType = getInput().getType();
  Type resultType = getParentOp().getType();
  if (inputType.getTypeID() != resultType.getTypeID())
    return emitOpError() << "expects the input to be of the monad of the "
                            "enclosing monad.do, got "
                         << inputType << " in a monad.do producing "
                         << resultType;

  TypeRange valueTypes = inputType.getValueTypes();
  if (getNext()->getArgumentTypes() != valueTypes)
    return emitOpError() << "expects the successor to take arguments of types ("
                         << valueTypes << ")";
  return success();
}

/// Returns the operands passed to the successor: none are forwarded, and the
/// bind produces one argument of each value type of the input.
SuccessorOperands MonadBindOp::getSuccessorOperands(unsigned index) {
  assert(index == 0 && "invalid successor index");
  return SuccessorOperands(getInput().getType().getValueTypes().size(),
                           MutableOperandRange(getOperation(), 0, 0));
}

//===----------------------------------------------------------------------===//
// MonadYieldOp
//===----------------------------------------------------------------------===//

/// Verifies that the yielded value is of the result type of the enclosing
/// `monad.do`.
LogicalResult MonadYieldOp::verify() {
  Type resultType = getParentOp().getType();
  if (getValue().getType() != resultType)
    return emitOpError() << "expects the yielded value to be of the result "
                            "type of the enclosing monad.do, "
                         << resultType << ", got " << getValue().getType();
  return success();
}
