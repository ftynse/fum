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
}

#endif // MONAD_TYPES
