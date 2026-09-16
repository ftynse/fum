//===- DepDialect.td - Dependent typing dialect ------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef DEP_DIALECT
#define DEP_DIALECT

include "mlir/IR/OpBase.td"

//===----------------------------------------------------------------------===//
// Dep dialect definition.
//===----------------------------------------------------------------------===//

def Dep_Dialect : Dialect {
    let name = "dep";
    let summary = "A dialect for dependent typing in MLIR";
    let description = [{
      This is highly unstable, proceed with caution.
    }];
    let cppNamespace = "::mlir::dep";

    let useDefaultTypePrinterParser = 1;
    let extraClassDeclaration = [{
        // Register types with the dialect.
        void registerTypes();
    }];
}

//===----------------------------------------------------------------------===//
// Base dep operation definition.
//===----------------------------------------------------------------------===//

class Dep_Op<string mnemonic, list<Trait> traits = []> :
        Op<Dep_Dialect, mnemonic, traits>;

#endif // DEP_DIALECT
