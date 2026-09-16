//===- DepOpInterfaces.td ----------------------------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Interfaces for operations working with dependent types, e.g., binding
// values to type parameters.
//
//===----------------------------------------------------------------------===//

include "mlir/IR/Interfaces.td"

def DepBinderOpInterface : OpInterface<"DepBinderOpInterface"> {
  let description = [{
    Operations implementing this interface may bind SSA values to type
    parameters used in dependent types.
  }];

  let cppNamespace = "::mlir::dep";

  let methods = [
    InterfaceMethod<
      /*desc=*/[{
        Return a list of Value/Attribute pairs, each of which defines a
        dependent type parameter binding. That is, the value is bound to the
        parameter usable inside a dependent type.
      }],
      /*returnType=*/"::llvm::SmallVector<std::pair<::mlir::Value, ::mlir::Attribute>>",
      /*name=*/"getBindings",
      /*arguments=*/(ins)
    >
  ];

  let extraClassDeclaration = [{
    /// Return the dependent type parameter object the given value binds to in
    /// this operation, or a null attribute if the value is not bound by this
    /// operation (it may still be bound by an ancestor).
    ::mlir::Attribute getBoundParam(::mlir::Value value);

    /// Return the value this dependent type parameter binds to in this
    /// in this operation, or a null value if the parameter is not introduced
    /// by this operation (it may still be introduced by an ancestor).
    ::mlir::Value getBoundValue(::mlir::Attribute param);
  }];

  let verify = [{
    return ::mlir::dep::verifyDependentTypeUsage($_op);
  }];
  let verifyWithRegions = 1;
}
