//===- MonadOps.cpp - Monad dialect ops -------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Monad/IR/MonadOps.h"
#include "fum/Dialect/ADT/IR/ADTOps.h"
#include "fum/Dialect/Monad/IR/MonadDialect.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/OpImplementation.h"
#include "llvm/ADT/STLExtras.h"

using namespace mlir;
using namespace mlir::monad;

#define GET_OP_CLASSES
#include "fum/Dialect/Monad/IR/MonadOps.cpp.inc"

//===----------------------------------------------------------------------===//
// MonadDoOp
//===----------------------------------------------------------------------===//

/// Verifies block predecessors and that all terminators belong to Monad.
LogicalResult MonadDoOp::verifyRegions() {
  for (Block &block : llvm::drop_begin(getBody())) {
    if (!block.getSinglePredecessor())
      return emitOpError()
             << "expects every block except the first to have exactly one "
                "predecessor";
  }
  for (Block &block : getBody()) {
    Operation *terminator = block.getTerminator();
    if (!isa_and_nonnull<MonadDialect>(terminator->getDialect()) &&
        !isa<adt::SwitchOp>(terminator))
      return emitOpError() << "expects every block terminator to belong to "
                              "the monad dialect, or to be adt.switch";
  }
  return success();
}

//===----------------------------------------------------------------------===//
// MonadBindOp
//===----------------------------------------------------------------------===//

/// Verifies that the input type allows binding it in the enclosing
/// `monad.do` with the arguments of the successor.
LogicalResult MonadBindOp::verify() {
  MonadTypeInterface inputType = getInput().getType();
  if (!inputType.areBindTypesCompatible(getParentOp().getType(),
                                        getNext()->getArgumentTypes()))
    return emitOpError() << "expects the input and the successor arguments to "
                            "be compatible with the enclosing monad.do";
  return success();
}

/// Returns the operands passed to the successor: none are forwarded, and the
/// bind produces every argument of the successor.
SuccessorOperands MonadBindOp::getSuccessorOperands(unsigned index) {
  assert(index == 0 && "invalid successor index");
  return SuccessorOperands(getNext()->getNumArguments(),
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

//===----------------------------------------------------------------------===//
// MonadEitherBranchOp
//===----------------------------------------------------------------------===//

/// Verifies that the successors take the values of their side.
LogicalResult MonadEitherBranchOp::verify() {
  EitherType inputType = getInput().getType();
  if (getLeft()->getArgumentTypes() != TypeRange(inputType.getLeftType()))
    return emitOpError() << "expects the left successor to take one argument "
                            "of type "
                         << inputType.getLeftType();
  if (getRight()->getArgumentTypes() != TypeRange(inputType.getValueTypes()))
    return emitOpError()
           << "expects the right successor to take arguments of types ("
           << inputType.getValueTypes() << ")";
  return success();
}

/// The branch produces the successor arguments and forwards no operands.
SuccessorOperands MonadEitherBranchOp::getSuccessorOperands(unsigned index) {
  assert(index < 2 && "invalid successor index");
  unsigned produced =
      index == 0 ? 1 : getInput().getType().getValueTypes().size();
  return SuccessorOperands(produced, MutableOperandRange(getOperation(), 0, 0));
}
