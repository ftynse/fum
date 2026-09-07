//===- DepTypes.td - Dependent types -----------------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef DEP_TYPES
#define DEP_TYPES

include "mlir/IR/AttrTypeBase.td"
include "fum/Dialect/Dep/IR/DepDialect.td"
include "fum/Dialect/Dep/Interfaces/DepTypeInterfaces.td"

//===----------------------------------------------------------------------===//
// Dep type definitions
//===----------------------------------------------------------------------===//

def DepBitVectorType : TypeDef<Dep_Dialect, "DependentBitVector",
    [DeclareTypeInterfaceMethods<DepTypeInterface>]> {
  let mnemonic = "bitvector";
  let description = [{
    Bit-vector type with dependent width.
  }];
  // TODO: turn this into a SymbolRefAttr or a dedicated attr.
  // TODO: consider having AffineExpr here, maybe some extension thereof,
  // based on dependent ML restricting dependent types to Presburger arithmetic
  // to ensure decidability
  let parameters = (ins StringRefParameter<"width of the bit-vector">:$width);
  let assemblyFormat = "`<` $width `>`";

  let extraClassDeclaration = [{
    ::llvm::SmallVector<::mlir::Attribute> getParams() {
      return {::mlir::StringAttr::get(getContext(), getWidth())};
    }
  }];
}

#endif // DEP_TYPES
