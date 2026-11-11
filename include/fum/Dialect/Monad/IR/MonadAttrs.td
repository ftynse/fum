//===- MonadAttrs.td - Monad dialect attributes ------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MONAD_ATTRS
#define MONAD_ATTRS

include "mlir/IR/AttrTypeBase.td"
include "fum/Dialect/Monad/IR/MonadDialect.td"

//===----------------------------------------------------------------------===//
// Monad attribute definitions
//===----------------------------------------------------------------------===//

class Monad_Attr<string name, string attrMnemonic, list<Trait> traits = []>
    : AttrDef<Monad_Dialect, name, traits> {
  let mnemonic = attrMnemonic;
}

def MonadErrorAttr : Monad_Attr<"Error", "error"> {
  let summary = "Named error";
  let description = [{
    `#monad.error<"name">` names an error that a failure of the either monad
    can carry. Errors are compile-time names: no value has an error type, and
    two errors are the same exactly when their names are.

    ```mlir
    #overflow = #monad.error<"overflow">
    ```
  }];
  let parameters = (ins StringRefParameter<"name of the error">:$name);
  let assemblyFormat = "`<` $name `>`";
  let genVerifyDecl = 1;
}

#endif // MONAD_ATTRS
