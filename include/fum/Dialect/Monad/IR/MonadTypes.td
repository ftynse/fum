//===- MonadTypes.td - Monad dialect types -----------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MONAD_TYPES
#define MONAD_TYPES

include "mlir/IR/AttrTypeBase.td"
include "fum/Dialect/Monad/IR/MonadDialect.td"
include "fum/Dialect/Monad/Interfaces/MonadTypeInterfaces.td"

//===----------------------------------------------------------------------===//
// Monad type definitions
//===----------------------------------------------------------------------===//

class Monad_Type<string name, string typeMnemonic, list<Trait> traits = []>
    : TypeDef<Monad_Dialect, name, traits> {
  let mnemonic = typeMnemonic;
}

def MonadMaybeType : Monad_Type<"Maybe", "maybe", [MonadTypeInterface]> {
  let summary = "Maybe monad type";
  let description = [{
    A value of type `!monad.maybe<T1, ..., Tn>` is either `some` value
    carrying one value of each type `T1`, ..., `Tn`, or `none`, which carries
    nothing. The list of value types may be empty.
  }];
  let parameters = (ins
      OptionalArrayRefParameter<"::mlir::Type", "value types">:$valueTypes);
  let assemblyFormat = "`<` custom<ValueTypes>($valueTypes) `>`";
  let extraClassDeclaration = [{
    /// Returns the maybe type with the given value types.
    MonadTypeInterface cloneWithValueTypes(::mlir::TypeRange valueTypes) const;
  }];
}

def MonadEitherType : Monad_Type<"Either", "either", [MonadTypeInterface]> {
  let summary = "Either monad type";
  let description = [{
    A value of type `!monad.either<[T1, ..., Tn] throws {E1, ..., Em}>` is
    either a success carrying one value of each type `T1`, ..., `Tn`, or a
    failure carrying exactly one error from the set `E1`, ..., `Em`. The value
    types are an ordered list and the errors a set; both may be empty. The
    errors are kept sorted by name and are distinct; the parser accepts them in
    any order.

    ```mlir
    // Either an i32, or an overflow or a division by zero.
    !monad.either<[i32] throws {#monad.error<"div_by_zero">,
                                #monad.error<"overflow">}>
    ```
  }];
  let parameters = (ins
      OptionalArrayRefParameter<"::mlir::Type", "value types">:$valueTypes,
      OptionalArrayRefParameter<"::mlir::monad::ErrorAttr", "errors">:$errors);
  let assemblyFormat = [{
    `<` `[` custom<ValueTypes>($valueTypes) `]` `throws`
    custom<ErrorSet>($errors) `>`
  }];
  let genVerifyDecl = 1;
  let extraClassDeclaration = [{
    /// Returns the either type with the given value types and the errors of
    /// this type.
    MonadTypeInterface cloneWithValueTypes(::mlir::TypeRange valueTypes) const;
  }];
}

#endif // MONAD_TYPES
