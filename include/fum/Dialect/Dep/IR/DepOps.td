//===- DepOps.td - Dep dialect ops -------------------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef DEP_OPS
#define DEP_OPS

include "fum/Dialect/Dep/IR/DepTypes.td"
include "fum/Dialect/Dep/Interfaces/DepOpInterfaces.td"

include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/IR/BuiltinAttributeInterfaces.td"
include "mlir/IR/OpAsmInterface.td"
include "mlir/Interfaces/InferIntRangeInterface.td"
include "mlir/IR/SymbolInterfaces.td"

def DepFuncOp : Dep_Op<"func", [
    SymbolName,
    SymbolVisibility,
    DeclareOpInterfaceMethods<DepBinderOpInterface>]> {
  let summary = "Function accepting dependent types";
  let description = [{
    Represents a function operating on dependent types and serving as a scope
    for binding values into type parameters. The arguments of the function
    may use dependent types including parameters bound in the function itself.
    For example, the following function accepts and returns bitvector of width
    specified by the %szA` argument:

    ```mlir
    dep.func @allowed(%szA: i32, %A: !dep.bitvector<"szA">)
    -> !dep.bitvector<"szA">
    binds {
      %szA -> "szA"
    }
    ```

    Functions may have a body, in which case the value names introduced in the
    signature are visible directly in it, or be body-less declarations.

    Additionally, such functions may establish contracts between values used as
    dependent type parameters. The `requires` region specifies the pre-condition
    as a single-block region containing only pure operations and yielding an
    `i1` value that indicates whether the pre-condition is satisfied. The
    `ensures` region specifies the post-condition guaranteed by the function
    as a similar block. For example, the function definition above may require
    the bitvector width to be positive as:

    ```mlir
    dep.func @allowed(%szA: i32, %A: !dep.bitvector<"szA">)
    -> !dep.bitvector<"szA">
    binds {
      %szA -> "szA"
    }
    requires {
    ^bb0(%arg0: i32):
      %c0 = arith.constant 0 : i32
      %okay = arith.cmpi gt, %arg0, %c0 : i32
      dep.yield %okay : i1
    }
    ```

    Note that these single-block regions must have the explicit block header.
    Their blocks have as arguments all the values from the function signature
    that are bound to dependent type parameters by the `binds` clause, in the
    same order as they appear in the signature (the clause itself may list them
    in a different order).
  }];
  let arguments = (ins
    SymbolNameAttr:$sym_name,
    TypeAttrOf<FunctionType>:$function_type,
    ArrayAttr:$binds, // TODO: pairs of TypeParamAttr/StringAttr and OperandPositionAttr/int
    OptionalAttr<StrAttr>:$sym_visibility
  );
  let regions = (region
    MaxSizedRegion<1>:$requires,
    MaxSizedRegion<1>:$ensures,
    AnyRegion:$body
  );
  let hasVerifier = 1;
  let hasCustomAssemblyFormat = 1;

  let extraClassDeclaration = [{
    int64_t getMaxBindablePosition() {
      return getFunctionType().getNumInputs();
    }

    ::mlir::Type getBoundValueType(int64_t position) {
      return getFunctionType().getInputs()[position];
    }
  }];
}

def DepCallOp : Dep_Op<"call"> {
  let summary = "Call a function accepting dependent types";
  let arguments = (ins
    SymbolRefAttr:$callee,
    Variadic<AnyType>:$operands
  );
  let results = (outs Variadic<AnyType>:$results);
  let assemblyFormat =
      "$callee `(` $operands `)` attr-dict `:` functional-type($operands, $results)";
}

def DepBindOp : Dep_Op<"bind", [
    DeclareOpInterfaceMethods<DepBinderOpInterface>]> {
  let summary = "Binds values to parameters of dependent types inline";
  let description = [{
    This is an inline counter-part of `dep.func`.
  }];
  let arguments = (ins
    ArrayAttr:$binds, // TODO: pairs of TypeParamAttr/StringAttr and OperandPositionAttr/int
    Variadic<AnyType>:$operands
  );
  let results = (outs Variadic<AnyType>:$results);
  let regions = (region
    MaxSizedRegion<1>:$requires,
    MaxSizedRegion<1>:$ensures,
    AnyRegion:$body);
  let hasVerifier = 1;
  let hasCustomAssemblyFormat = 1;

  let extraClassDeclaration = [{
    int64_t getMaxBindablePosition() {
      return getNumOperands();
    }

    ::mlir::Type getBoundValueType(int64_t position) {
      return getOperand(position).getType();
    }
  }];
}

def DepYieldOp: Dep_Op<"yield", [Terminator, Pure]> {
  let summary = "yield-like terminator for Dep dialect ops with regions";
  let arguments = (ins Variadic<AnyType>:$operands);
  let assemblyFormat = "($operands^)? attr-dict (`:` type($operands)^)?";
}

def DepCheckTypeParamsEqual : Dep_Op<"check_type_params_equal"> {
  let summary = "[testing] Check if two dependent types are equal in local context";
  let description = [{
    Require that two dependent types used in attributes can be proved to be equal
    in the context where the operation itself is placed. By definition, dependent
    types depend on values in the surrounding context so a global type performed by
    MLIR infrastructure may be insufficient.
  }];
  let arguments = (ins TypeAttrOf<DepBitVectorType>:$lhs,
                       TypeAttrOf<DepBitVectorType>:$rhs);
}


#endif // DEP_OPS
