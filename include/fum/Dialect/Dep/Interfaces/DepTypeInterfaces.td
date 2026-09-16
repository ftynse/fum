//===- DepTypeInterfaces.td - Dependent type interfaces ----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef FUM_DIALECT_DEP_INTERFACES_DEPTYPEINTERFACES_TD
#define FUM_DIALECT_DEP_INTERFACES_DEPTYPEINTERFACES_TD

include "mlir/IR/Interfaces.td"

def DepTypeParamInterface : TypeInterface<"DepTypeParamInterface"> {
  let description = [{
    Tag interface indicating that the type may be used for values
    of dependent type parameters.
  }];
  let cppNamespace = "::mlir::dep";
}

def DepTypeInterface : TypeInterface<"DepTypeInterface"> {
  let description = [{
    Interface for dependent types. The identity of dependent types indirectly
    depends on a value from a surrounding context. Since MLIR itself does not
    allow referring to a value from inside a type, the indirection happens
    through a binder attribute. A binder operation (see DepBinderOpInterface)
    associates an SSA value visible for the operation (either an operand
    following the usual SSA rules, or an entry block argument of the binder
    operation) with an attribute. A dependent type uses the attribute to
    refer to a value.

    In such a context, type checking must be performed separately by a
    dedicated pass rather than by the generic MLIR type checker that can only
    check for structural equality, that is, that dependent attributes
    themselves match (or otherwise satisfy the type check) without attempting
    to reason about the values bound to those attributes.
  }];
  let cppNamespace = "::mlir::dep";

  let methods = [
    InterfaceMethod<
      /*desc=*/[{
        Returns the list of parameters the type depends on.
      }],
      /*returnType=*/"::llvm::SmallVector<::mlir::Attribute>",
      /*name=*/"getParams",
      /*arguments=*/(ins)
    >
  ];

  // TODO: check that all params implement DepTypeParamInterface, but there
  // is no way to inject verifiers into the type...
//   let verify = [{ return ::mlir::dep::verifyDepTypeInterface($_self); }];
}

#endif // FUM_DIALECT_DEP_INTERFACES_DEPTYPEINTERFACES_TD
