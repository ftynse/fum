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
    A value of type `!monad.either<L, R1, ..., Rn>` is either a left carrying
    one value of type `L`, or a right carrying one value of each type `R1`,
    ..., `Rn`. It has exactly two constructors, as Haskell's `Either`: a left
    may hold any type, not only an error. The right types are the value types
    of the monad. Both sides are always written: a right that carries nothing
    is written `none`, as in Haskell's `Either L ()`, and `none` cannot
    appear among other right types.

    `monad.return` creates a right and `monad.either.left` a left.
    `monad.bind` continues on a right and ends the enclosing `monad.do` with
    a left, so its input must have the left type of the `monad.do`.
    `monad.either.branch` branches on the side.

    ```mlir
    // Either an i32 error code, or an f32.
    !monad.either<i32, f32>
    // Either an i32 error code, or nothing.
    !monad.either<i32, none>
    ```
  }];
  let parameters = (ins
      "::mlir::Type":$leftType,
      OptionalArrayRefParameter<"::mlir::Type", "value types">:$valueTypes);
  let assemblyFormat = "`<` $leftType `,` custom<RightTypes>($valueTypes) `>`";
  let genVerifyDecl = 1;
  let extraClassDeclaration = [{
    /// Returns the either type with the given value types and the left type
    /// of this type.
    MonadTypeInterface cloneWithValueTypes(::mlir::TypeRange valueTypes) const;
  }];
}

#endif // MONAD_TYPES
