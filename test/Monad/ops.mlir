// RUN: fum-opt %s | fum-opt | FileCheck %s
// RUN: fum-opt %s --mlir-print-op-generic | fum-opt | FileCheck %s

// Round-trip the maybe type with one, several, no, and nested value types.
// CHECK-LABEL: func.func private @maybe_types
// CHECK-SAME: !monad.maybe<i32>
// CHECK-SAME: !monad.maybe<i32, f32>
// CHECK-SAME: !monad.maybe<>
// CHECK-SAME: !monad.maybe<!monad.maybe<i32>>
func.func private @maybe_types(!monad.maybe<i32>, !monad.maybe<i32, f32>,
                               !monad.maybe<>, !monad.maybe<!monad.maybe<i32>>)

// Wrap several values, or none, as a success.
// CHECK-LABEL: func.func @wrap_values
// CHECK-SAME: (%[[A:.+]]: i32, %[[B:.+]]: f32)
// CHECK: monad.return %[[A]], %[[B]] : !monad.maybe<i32, f32>
// CHECK: monad.return : !monad.maybe<>
func.func @wrap_values(%a: i32, %b: f32)
    -> (!monad.maybe<i32, f32>, !monad.maybe<>) {
  %values = monad.return %a, %b : !monad.maybe<i32, f32>
  %nothing = monad.return : !monad.maybe<>
  return %values, %nothing : !monad.maybe<i32, f32>, !monad.maybe<>
}

// Create the maybe value that carries no value.
// CHECK-LABEL: func.func @maybe_none
// CHECK: monad.maybe.none : !monad.maybe<f32>
func.func @maybe_none() -> !monad.maybe<f32> {
  %result = monad.maybe.none : !monad.maybe<f32>
  return %result : !monad.maybe<f32>
}

// Bind the value carried by a maybe to a computation producing a maybe of
// another type.
// CHECK-LABEL: func.func @bind
// CHECK-SAME: (%[[INPUT:.+]]: !monad.maybe<i32>)
// CHECK: monad.do : !monad.maybe<f32> {
// CHECK: monad.bind %[[INPUT]], ^[[NEXT:.+]] : !monad.maybe<i32>
// CHECK: ^[[NEXT]](%{{.*}}: i32):
// CHECK: %[[WRAPPED:.+]] = monad.return %{{.*}} : !monad.maybe<f32>
// CHECK: monad.yield %[[WRAPPED]] : !monad.maybe<f32>
func.func @bind(%input: !monad.maybe<i32>) -> !monad.maybe<f32> {
  %result = monad.do : !monad.maybe<f32> {
    monad.bind %input, ^next : !monad.maybe<i32>
  ^next(%value: i32):
    %converted = arith.sitofp %value : i32 to f32
    %wrapped = monad.return %converted : !monad.maybe<f32>
    monad.yield %wrapped : !monad.maybe<f32>
  }
  return %result : !monad.maybe<f32>
}

// Bind a maybe carrying several values, and one carrying none.
// CHECK-LABEL: func.func @bind_values
// CHECK: monad.bind %{{.*}}, ^[[NEXT:.+]] : !monad.maybe<i32, i32>
// CHECK: ^[[NEXT]](%{{.*}}: i32, %{{.*}}: i32):
// CHECK: monad.bind %{{.*}}, ^[[GUARDED:.+]] : !monad.maybe<>
// CHECK: ^[[GUARDED]]:
func.func @bind_values(%pair: !monad.maybe<i32, i32>, %guard: !monad.maybe<>)
    -> !monad.maybe<i32> {
  %result = monad.do : !monad.maybe<i32> {
    monad.bind %pair, ^next : !monad.maybe<i32, i32>
  ^next(%a: i32, %b: i32):
    monad.bind %guard, ^guarded : !monad.maybe<>
  ^guarded:
    %sum = arith.addi %a, %b : i32
    %wrapped = monad.return %sum : !monad.maybe<i32>
    monad.yield %wrapped : !monad.maybe<i32>
  }
  return %result : !monad.maybe<i32>
}

// A single-block computation needs no predecessor for its entry block.
// CHECK-LABEL: func.func @do_single_block
// CHECK: monad.do : !monad.maybe<i32> {
// CHECK: monad.yield %{{.*}} : !monad.maybe<i32>
func.func @do_single_block(%input: !monad.maybe<i32>) -> !monad.maybe<i32> {
  %result = monad.do : !monad.maybe<i32> {
    monad.yield %input : !monad.maybe<i32>
  }
  return %result : !monad.maybe<i32>
}

// The right side is a list of types, or none for a right without value.
// CHECK-LABEL: func.func private @either_types
// CHECK-SAME: !monad.either<i32, f32>
// CHECK-SAME: !monad.either<i32, none>
func.func private @either_types(!monad.either<i32, f32>, !monad.either<i32, none>)

// Build a left and a right, and branch on the side.
// CHECK-LABEL: func.func @either_branch
// CHECK: monad.either.left %{{.*}} : !monad.either<i32, f32>
// CHECK: monad.return %{{.*}} : !monad.either<i32, f32>
// CHECK: monad.either.branch %{{.*}}, left ^[[LEFT:.*]], right ^[[RIGHT:.*]] : !monad.either<i32, f32>
// CHECK: ^[[LEFT]](%{{.*}}: i32):
// CHECK: ^[[RIGHT]](%{{.*}}: f32):
func.func @either_branch(%code: i32, %value: f32, %flag: i1) -> f32 {
  %left = monad.either.left %code : !monad.either<i32, f32>
  %right = monad.return %value : !monad.either<i32, f32>
  %either = arith.select %flag, %left, %right : !monad.either<i32, f32>
  monad.either.branch %either, left ^left, right ^right : !monad.either<i32, f32>
^left(%error: i32):
  %converted = arith.sitofp %error : i32 to f32
  return %converted : f32
^right(%result: f32):
  return %result : f32
}

// Bind a right with no value and a right with a value, inside a do of the
// same left type and other right types; a left ends the do.
// CHECK-LABEL: func.func @either_bind
// CHECK: monad.do : !monad.either<i32, f32> {
// CHECK: monad.bind %{{.*}}, ^[[CHECKED:.*]] : !monad.either<i32, none>
// CHECK: ^[[CHECKED]]:
// CHECK: monad.bind %{{.*}}, ^[[NEXT:.*]] : !monad.either<i32, i64>
// CHECK: ^[[NEXT]](%{{.*}}: i64):
func.func @either_bind(%check: !monad.either<i32, none>,
                       %input: !monad.either<i32, i64>) -> !monad.either<i32, f32> {
  %result = monad.do : !monad.either<i32, f32> {
    monad.bind %check, ^checked : !monad.either<i32, none>
  ^checked:
    monad.bind %input, ^next : !monad.either<i32, i64>
  ^next(%value: i64):
    %converted = arith.sitofp %value : i64 to f32
    %success = monad.return %converted : !monad.either<i32, f32>
    monad.yield %success : !monad.either<i32, f32>
  }
  return %result : !monad.either<i32, f32>
}
