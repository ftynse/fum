//===- DepOpInterfaces.cpp - Dependent Type Interfaces --------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Dep/Interfaces/DepOpInterfaces.h"
#include "fum/Dialect/Dep/Interfaces/DepTypeInteraces.h"
#include "mlir/IR/OpImplementation.h"

#include "fum/Dialect/Dep/Interfaces/DepOpInterfaces.cpp.inc"

using namespace mlir;
using namespace mlir::dep;

LogicalResult mlir::dep::verifyTypesInOps(
    function_ref<LogicalResult(Location, Type)> checkTypeSingle,
    Operation *root) {
  // Verify usage of dependent type parameters on this type and any nested type,
  // including indirectly via attributes.
  auto checkType = [&](Location loc, Type type) -> LogicalResult {
    // Avoid recursively calling itself from walkers, they will traverse the
    // nested structure anyway.
    AttrTypeWalker walker;
    walker.addWalk([&](DepTypeInterface subType) {
      if (failed(checkTypeSingle(loc, subType)))
        return WalkResult::interrupt();
      return WalkResult::advance();
    });
    walker.addWalk([&](TypeAttr typeAttr) {
      if (failed(checkTypeSingle(loc, typeAttr.getValue())))
        return WalkResult::interrupt();
      return WalkResult::advance();
    });
    if (walker.walk(type).wasInterrupted())
      return failure();

    return success();
  };

  WalkResult walkResult = root->walk<WalkOrder::PreOrder>([&](Operation *op) {
    // Don't enter ops with this interface, they will be visited separately.
    if (isa<dep::DepBinderOpInterface>(op) && op != root)
      return WalkResult::skip();

    for (Type t : op->getOperandTypes()) {
      if (failed(checkType(op->getLoc(), t)))
        return WalkResult::interrupt();
    }
    for (Type t : op->getResultTypes()) {
      if (failed(checkType(op->getLoc(), t)))
        return WalkResult::interrupt();
    }
    for (Region &region : op->getRegions()) {
      for (Block &block : region.getBlocks()) {
        for (BlockArgument arg : block.getArguments()) {
          if (failed(checkType(arg.getLoc(), arg.getType())))
            return WalkResult::interrupt();
        }
      }
    }
    for (NamedAttribute named : op->getAttrs()) {
      WalkResult subResult = named.getValue().walk([&](TypeAttr typeAttr) {
        if (failed(checkType(op->getLoc(), typeAttr.getValue())))
          return WalkResult::interrupt();
        return WalkResult::advance();
      });
      if (subResult.wasInterrupted())
        return WalkResult::interrupt();
    }
    return WalkResult::advance();
  });

  return failure(walkResult.wasInterrupted());
}

/// Emits errors if dependent types are used within the region have all their
/// parameters bound.
LogicalResult mlir::dep::verifyDependentTypeUsage(Operation *root) {
  DenseSet<Attribute> boundTypeParams;
  for (Operation *op = root; op != nullptr; op = op->getParentOp()) {
    auto iface = dyn_cast<DepBinderOpInterface>(op);
    if (!iface)
      continue;

    boundTypeParams.insert_range(llvm::make_second_range(iface.getBindings()));
  }

  auto checkTypeSingle = [&](Location loc, Type type) -> LogicalResult {
    auto depType = dyn_cast<DepTypeInterface>(type);
    if (!depType)
      return success();

    for (Attribute attr : depType.getParams()) {
      if (!boundTypeParams.contains(attr)) {
        return emitError(loc)
               << "dependent type " << type << " uses type parameter " << attr
               << " not bound to a value";
      }
    }
    return success();
  };

  return verifyTypesInOps(checkTypeSingle, root);
}

Attribute dep::DepBinderOpInterface::getBoundParam(Value value) {
  for (auto [v, param] : getBindings())
    if (v == value)
      return param;
  return Attribute();
}

Value dep::DepBinderOpInterface::getBoundValue(Attribute param) {
  for (auto [value, p] : getBindings())
    if (p == param)
      return value;
  return Value();
}
