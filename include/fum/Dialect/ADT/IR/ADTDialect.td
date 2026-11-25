//===- ADTDialect.td - ADT dialect -------------------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef ADT_DIALECT
#define ADT_DIALECT

include "mlir/IR/OpBase.td"

def ADT_Dialect : Dialect {
  let name = "adt";
  let summary = "Finite sum types";
  let description = [{
    Finite, non-recursive sum types, the operations that build their values,
    and the case analysis on them.
  }];
  let cppNamespace = "::mlir::adt";
  let useDefaultTypePrinterParser = 1;
  let extraClassDeclaration = [{
    /// Registers the types of the dialect.
    void registerTypes();
  }];
}

class ADT_Op<string mnemonic, list<Trait> traits = []> :
    Op<ADT_Dialect, mnemonic, traits>;

#endif // ADT_DIALECT
