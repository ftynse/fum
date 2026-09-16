//===- DepPasses.td - Dep dialect passes -------------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef DEP_PASS
#define DEP_PASS

include "mlir/Pass/PassBase.td"

def DepTypeCheckPass : Pass<"dependent-type-check"> {
  let summary = "Perform type-checking of dependent types and report errors";
  let dependentDialects = [
    "::mlir::func::FuncDialect",
    "::mlir::arith::ArithDialect"
  ];
}


#endif // DEP_PASS
