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
include "mlir/IR/BuiltinAttributes.td"
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

def DepConstructedType : TypeDef<Dep_Dialect, "ConstructedType",
    [DeclareTypeInterfaceMethods<DepTypeInterface>]> {
  let mnemonic = "constructed";
  let parameters = (ins "SymbolRefAttr":$constructor,
                        "ArrayAttr":$typeParams);
  let hasCustomAssemblyFormat = 1;
  let genVerifyDecl = 1;

  let extraClassDeclaration = [{
    ::llvm::SmallVector<::mlir::Attribute> getParams() {
      ::llvm::SmallVector<::mlir::Attribute> params;
      params.append(getTypeParams().begin(), getTypeParams().end());
      return params;
    }

    ::llvm::SmallVector<::mlir::SymbolRefAttr> getReferencedSymbols() {
      return {getConstructor()};
    }
  }];
}

def DepTypeType : TypeDef<Dep_Dialect, "DependentType"> {
  let mnemonic = "type";
  let description = [{
    Opaque type for representing other types as values. That is, a value of
    `!dep.type` is itself a type. This allows us to manipulate types as
    first-class objects in the IR and blur the boundary between types and
    values, which is desired, e.g., in type constructors.
  }];
}

#endif // DEP_TYPES
