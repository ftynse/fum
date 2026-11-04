//===- MonadTypeInterfaces.td - Monad type interfaces ------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef FUM_DIALECT_MONAD_INTERFACES_MONADTYPEINTERFACES_TD
#define FUM_DIALECT_MONAD_INTERFACES_MONADTYPEINTERFACES_TD

include "mlir/IR/Interfaces.td"

def MonadTypeInterface : TypeInterface<"MonadTypeInterface"> {
  let description = [{
    Interface for monadic types. A monadic type `M<T1, ..., Tn>` applies a
    type constructor `M` to a list of value types. Values of monadic types are
    built with `monad.return` and composed with `monad.bind`, which read the
    value types through this interface.
  }];
  let cppNamespace = "::mlir::monad";

  let methods = [
    InterfaceMethod<
      /*desc=*/[{
        Returns the value types to which the type constructor is applied.
      }],
      /*returnType=*/"::llvm::ArrayRef<::mlir::Type>",
      /*name=*/"getValueTypes",
      /*arguments=*/(ins)
    >
  ];
}

#endif // FUM_DIALECT_MONAD_INTERFACES_MONADTYPEINTERFACES_TD
