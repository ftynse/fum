//===- DepPasses.cpp - Dep passes -------------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#include "mlir/Transforms/Passes.h"
#include "fum/Dialect/Dep/Interfaces/DepOpInterfaces.h"
#include "fum/Dialect/Dep/Interfaces/DepTypeInteraces.h"
#include "mlir/Analysis/SliceAnalysis.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/IRMapping.h"
#include "mlir/IR/Matchers.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Rewrite/FrozenRewritePatternSet.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

#include "fum/Dialect/Dep/Transforms/Passes.h"

namespace mlir::dep {
#define GEN_PASS_DEF_DEPTYPECHECKPASS
#include "fum/Dialect/Dep/Transforms/Passes.h.inc"

// Verifies that dependent types are not used outside of any binder operation.
static LogicalResult verifyDepTypeUsageOutsideContext(Operation *root) {
  auto checkTypeSingle = [](Location loc, Type type) -> LogicalResult {
    if (!isa<DepTypeInterface>(type))
      return success();
    return emitError(loc)
           << "dependent type used outside of the binder context";
  };
  return verifyTypesInOps(checkTypeSingle, root);
}

// Perform contextual verification of dependent types anchored at the given
// function.
// TODO: this is a dirty prototype and needs significant improvement.
static LogicalResult verifyDepTypeCheck(dep::DepCheckTypeParamsEqual check) {
  if (check.getLhs().getWidth() == check.getRhs().getWidth())
    return success();

  auto findBoundValue = [&](StringRef name) -> Value {
    for (Operation *parent = check->getParentOp(); parent;
         parent = parent->getParentOp()) {
      // TODO: use binder interface
      if (auto binder = dyn_cast<dep::DepBindOp>(parent)) {
        for (ArrayRef<Attribute> bind :
             binder.getBinds().getAsValueRange<ArrayAttr>()) {
          assert(bind.size() == 2);
          if (cast<StringAttr>(bind[1]) == name) {
            return binder->getOperand(
                cast<IntegerAttr>(bind[0]).getValue().getSExtValue());
          }
        }
      } else if (auto func = dyn_cast<dep::DepFuncOp>(parent)) {
        for (ArrayRef<Attribute> bind :
             func.getBinds().getAsValueRange<ArrayAttr>()) {
          assert(bind.size() == 2);
          // TODO: not sure what to return here, the value is bound at the
          // function call place... for now, let's say it's the argument of the
          // main region, but I'm not sure
          if (cast<StringAttr>(bind[1]) == name) {
            return func.getBody().front().getArgument(
                cast<IntegerAttr>(bind[0]).getInt());
          }
        }
      }
    }
    return Value();
  };

  Value lhsValue = findBoundValue(check.getLhs().getWidth());
  Value rhsValue = findBoundValue(check.getRhs().getWidth());
  if (lhsValue == rhsValue)
    return success();

  // clone the relevant pieces of the IR
  // for this, we may need to find "free" values and turn them into function
  // arguments for simplicity, let's assume/check the slice doesn't traverse
  // regions, or only some controllable regions;  (alternatively, we could try
  // to (abstract) interpret the existing IR and avoid cloning)

  struct CloneFragment {
    SmallVector<Value> freeValues;
    SmallVector<Operation *> operations;
  };

  Location loc = check.getLoc();
  auto prepareCloning = [loc](Value boundValue) -> FailureOr<CloneFragment> {
    SetVector<Operation *> slice;
    SmallVector<Value> freeValues;
    if (failed(getBackwardSlice(boundValue, &slice)))
      return ::mlir::emitError(loc)
             << "failed to compute backward slice in dependent type check";
    if (auto *definingOp = boundValue.getDefiningOp()) {
      slice.insert(definingOp);
    } else {
      // TODO: it would be nice to annotate free values somehow so the user
      // knows what they map to in the original code.
      freeValues.push_back(boundValue);
    }

    DenseSet<Value> definedValues;
    for (Operation *op : slice) {
      definedValues.insert_range(op->getResults());
    }
    for (Operation *op : slice) {
      for (Value operand : op->getOperands()) {
        if (definedValues.contains(operand)) {
          if (Operation *definingOp = operand.getDefiningOp()) {
            // TODO: we should admit certain region crossings, but we will need
            // to know how to replicate
            if (definingOp->getParentRegion() != op->getParentRegion()) {
              ::mlir::emitError(loc)
                  << "NYI: region-crossing slice in dependent type check";
              return failure();
            }
          }
        } else {
          freeValues.push_back(operand);
        }
      }
    }
    return CloneFragment{freeValues, slice.takeVector()};
  };

  FailureOr<CloneFragment> lhsFragment = prepareCloning(lhsValue);
  if (failed(lhsFragment))
    return failure();
  FailureOr<CloneFragment> rhsFragment = prepareCloning(rhsValue);
  if (failed(rhsFragment))
    return failure();

  OpBuilder builder(check.getContext());
  SmallVector<Type> inputTypes = llvm::to_vector(llvm::concat<Type>(
      TypeRange(lhsFragment->freeValues), TypeRange(rhsFragment->freeValues)));
  OwningOpRef<func::FuncOp> f = func::FuncOp::create(
      loc, "__type_equality_check__",
      FunctionType::get(check.getContext(), inputTypes,
                        IntegerType::get(check.getContext(), 1)));
  Block *entry = f->addEntryBlock();

  IRMapping mapping;
  mapping.map(lhsFragment->freeValues,
              entry->getArguments().take_front(lhsFragment->freeValues.size()));
  mapping.map(rhsFragment->freeValues,
              entry->getArguments().take_back(rhsFragment->freeValues.size()));
  builder.setInsertionPointToStart(entry);
  for (Operation *op : lhsFragment->operations) {
    builder.clone(*op, mapping);
  }
  for (Operation *op : rhsFragment->operations) {
    builder.clone(*op, mapping);
  }

  // TODO: lhsValue may not be mapped at all if it's a block argument,
  // but it's not actually the fact that it's a block argument, but that it's
  // not defined in the function.
  //
  // at this point, these are just different values and we should fail the type
  // check

  Value checkerLhsValue = mapping.lookupOrNull(lhsValue);
  Value checkerRhsValue = mapping.lookupOrNull(rhsValue);
  if (!checkerLhsValue) {
    InFlightDiagnostic diag = emitError(check->getLoc())
                              << "couldn't partially evaluate the type "
                                 "parameter of the dependent type "
                              << check.getLhs();
    diag.attachNote(lhsValue.getLoc()) << "parameter value";
    return failure();
  }
  if (!checkerRhsValue) {
    InFlightDiagnostic diag = emitError(check->getLoc())
                              << "couldn't partially evaluate the type "
                                 "parameter of the dependent type "
                              << check.getRhs();
    diag.attachNote(rhsValue.getLoc()) << "parameter value";
    return failure();
  }

  Value comparisonResult =
      arith::CmpIOp::create(builder, loc, arith::CmpIPredicate::eq,
                            mapping.lookup(lhsValue), mapping.lookup(rhsValue));
  func::ReturnOp::create(builder, loc, comparisonResult);

  PassManager pm(check.getContext());
  pm.addPass(createCanonicalizerPass());
  pm.addPass(createCSEPass());
  pm.addPass(createCanonicalizerPass());
  if (failed(pm.run(*f)))
    return failure();

  APInt value;
  if (!matchPattern(cast<func::ReturnOp>(f->getRegion().front().getTerminator())
                        ->getOperand(0),
                    m_ConstantInt(&value)) ||
      !value.isOne()) {

    InFlightDiagnostic diag = check.emitError()
                              << "failed to prove dependent type equivalence";

    // TODO: ideally we don't materialize the string here.
    std::string output;
    llvm::raw_string_ostream os(output);
    f->print(os);
    diag.attachNote() << "function reduced to: " << os.str();
    return failure();
  }

  return success();
}

namespace {
class DepTypeCheckPass
    : public dep::impl::DepTypeCheckPassBase<DepTypeCheckPass> {
  void runOnOperation() override {
    if (failed(verifyDepTypeUsageOutsideContext(getOperation())))
      return signalPassFailure();

    WalkResult walkResult =
        getOperation()->walk([](dep::DepCheckTypeParamsEqual check) {
          if (failed(verifyDepTypeCheck(check)))
            return WalkResult::interrupt();
          return WalkResult::advance();
        });
    if (walkResult.wasInterrupted())
      return signalPassFailure();
  }
};
} // namespace

} // namespace mlir::dep
