//===- ADTOps.td - ADT dialect ops -------------------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef ADT_OPS
#define ADT_OPS

include "fum/Dialect/ADT/IR/ADTTypes.td"
include "mlir/Interfaces/ControlFlowInterfaces.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def ADT_MakeOp : ADT_Op<"make", [Pure]> {
  let summary = "Builds a value of one case of a sum";
  let description = [{
    Builds the case `case_name` of the result sum from one operand per field
    of the case.

    ```mlir
    %e = adt.make io(%code) : !adt.sum<div_by_zero, io(i32)>
    ```
  }];
  let arguments = (ins StrAttr:$case_name, Variadic<AnyType>:$fields);
  let results = (outs ADT_SumType:$result);
  let hasCustomAssemblyFormat = 1;
  let hasVerifier = 1;
}

def ADT_SwitchOp : ADT_Op<"switch", [
    Pure,
    Terminator,
    DeclareOpInterfaceMethods<BranchOpInterface>]> {
  let summary = "Branches on the case of a sum";
  let description = [{
    Branches to the successor of the case that the input holds, with the
    fields of the case as arguments. Without `default`, every case is listed.
    With `default`, written first, at least one case is not listed, and the
    `default` successor takes no arguments.

    ```mlir
    adt.switch %e : !adt.sum<div_by_zero, io(i32), overflow>, [
      default: ^other,
      io: ^io
    ]
    ```
  }];
  let arguments = (ins ADT_SumType:$input, StrArrayAttr:$case_names);
  let successors = (successor VariadicSuccessor<AnySuccessor>:$destinations);
  let hasCustomAssemblyFormat = 1;
  let hasVerifier = 1;
  let extraClassDeclaration = [{
    /// Returns the successor of the cases that are not listed, or null.
    ::mlir::Block *getDefaultDestination();
  }];
}

#endif // ADT_OPS
