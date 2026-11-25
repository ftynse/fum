//===- ADTTypes.td - ADT dialect types ---------------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef ADT_TYPES
#define ADT_TYPES

include "mlir/IR/AttrTypeBase.td"
include "fum/Dialect/ADT/IR/ADTDialect.td"

def ADT_SumType : TypeDef<ADT_Dialect, "Sum"> {
  let mnemonic = "sum";
  let summary = "Finite sum of named cases";
  let description = [{
    A value of type `!adt.sum<c1(T1, ..., Tk), c2, ...>` is one of the cases
    `c1`, `c2`, ..., with one value of each field type of that case. A case
    without fields is written without parentheses. There is at least one case
    and the names are distinct. The cases are a dictionary from names to
    field types, so they may be written in any order and are printed sorted
    by name.

    ```mlir
    !adt.sum<div_by_zero, io(i32)>
    ```
  }];
  let parameters = (ins "::mlir::DictionaryAttr":$cases);
  let hasCustomAssemblyFormat = 1;
  let genVerifyDecl = 1;
  let extraClassDeclaration = [{
    /// Returns the field types of the case named `name`, if there is one.
    std::optional<::llvm::SmallVector<::mlir::Type>>
    getCaseFields(::llvm::StringRef name) const;
  }];
}

#endif // ADT_TYPES
