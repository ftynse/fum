//===- MonadOps.td - Monad dialect ops ---------------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MONAD_OPS
#define MONAD_OPS

include "fum/Dialect/Monad/IR/MonadTypes.td"
include "mlir/Interfaces/ControlFlowInterfaces.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

//===----------------------------------------------------------------------===//
// Operations common to all monads
//===----------------------------------------------------------------------===//

def MonadReturnOp : Monad_Op<"return", [
    Pure,
    RangedTypesMatchWith<"value types match the value types of the result",
                         "result", "values",
                         "::llvm::cast<::mlir::monad::MonadTypeInterface>($_self).getValueTypes()">]> {
  let summary = "Wraps values into a monadic value";
  let description = [{
    Creates a monadic value from one value of each value type of the result,
    the `return` (or `pure`) of the monad. For the maybe monad, this is
    `some` value carrying the values.

    ```mlir
    %m = monad.return %a, %b : !monad.maybe<i32, f32>
    ```
  }];
  let arguments = (ins Variadic<AnyType>:$values);
  let results = (outs MonadTypeInterface:$result);
  let assemblyFormat = "$values attr-dict `:` qualified(type($result))";
}

def MonadDoOp : Monad_Op<"do", [RecursiveMemoryEffects]> {
  let summary = "Sequences monadic computations";
  let description = [{
    Runs its region, a sequence of monadic computations in the style of
    Haskell's do-notation, and produces the monadic value it yields. Blocks
    are continuations: `monad.bind` ends a block by binding the values of a
    monadic value to the arguments of the next block, and `monad.yield` ends
    the computation with its result. Every value bound in the region is of the
    same monad as the result: its type is the result type up to the value
    types. Every block except the first must have exactly
    one predecessor. Every block must end with a terminator from the monad
    dialect.

    How a bind continues depends on the monad. For the maybe monad, binding
    `some` value branches to the next block with the values it carries, and
    binding `none` ends the computation with `none`.

    Because a bind may leave the region, this operation does not implement
    `RegionBranchOpInterface`, and data-flow analyses treat its result
    conservatively.

    ```mlir
    %r = monad.do : !monad.maybe<f32> {
      monad.bind %m, ^next : !monad.maybe<i32>
    ^next(%x: i32):
      %y = arith.sitofp %x : i32 to f32
      %ok = monad.return %y : !monad.maybe<f32>
      monad.yield %ok : !monad.maybe<f32>
    }
    ```
  }];
  let results = (outs MonadTypeInterface:$result);
  let regions = (region MinSizedRegion<1>:$body);
  let hasRegionVerifier = 1;
  let assemblyFormat = "attr-dict `:` qualified(type($result)) $body";
}

def MonadBindOp : Monad_Op<"bind", [
    Terminator,
    HasParent<"MonadDoOp">,
    DeclareOpInterfaceMethods<BranchOpInterface>]> {
  let summary = "Binds the values of a monadic value to the next block";
  let description = [{
    Continues the enclosing `monad.do` with the values of the input bound to
    the arguments of the successor. The successor takes one argument
    of each value type of the input. These arguments are produced by the bind,
    which forwards no operands.

    ```mlir
    monad.bind %m, ^next : !monad.maybe<i32, f32>
    ^next(%a: i32, %b: f32):
    ```
  }];
  let arguments = (ins MonadTypeInterface:$input);
  let successors = (successor AnySuccessor:$next);
  let assemblyFormat = [{
    $input `,` $next attr-dict `:` qualified(type($input))
  }];
  let hasVerifier = 1;
}

def MonadYieldOp : Monad_Op<"yield", [
    Pure,
    Terminator,
    HasParent<"MonadDoOp">]> {
  let summary = "Ends a monadic computation with its result";
  let description = [{
    Ends the region of the enclosing `monad.do`, whose result becomes the
    yielded value.

    ```mlir
    monad.yield %m : !monad.maybe<f32>
    ```
  }];
  let arguments = (ins MonadTypeInterface:$value);
  let assemblyFormat = "$value attr-dict `:` qualified(type($value))";
  let hasVerifier = 1;
}

//===----------------------------------------------------------------------===//
// Maybe operations
//===----------------------------------------------------------------------===//

def MonadMaybeNoneOp : Monad_Op<"maybe.none", [Pure]> {
  let summary = "Creates the maybe value that carries no value";
  let description = [{
    Creates `none`, the maybe value that carries no value.

    ```mlir
    %m = monad.maybe.none : !monad.maybe<i32>
    ```
  }];
  let results = (outs MonadMaybeType:$result);
  let assemblyFormat = "attr-dict `:` qualified(type($result))";
}

#endif // MONAD_OPS
