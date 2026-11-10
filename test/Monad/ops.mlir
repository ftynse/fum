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

// Error used by the either tests.
#overflow_err = #monad.error<"overflow">

// Round-trip the error attribute.
// CHECK-LABEL: func.func private @error_attr
// CHECK-SAME: error = #monad.error<"overflow">
func.func private @error_attr() attributes {error = #overflow_err}

// Round-trip the either type with one, several, no, and nested value types,
// and with one, several, and no errors.
// CHECK-LABEL: func.func private @either_types
// CHECK-SAME: !monad.either<[i32] throws {#monad.error<"overflow">}>
// CHECK-SAME: !monad.either<[i8, i32] throws {#monad.error<"div_by_zero">, #monad.error<"overflow">}>
// CHECK-SAME: !monad.either<[] throws {#monad.error<"overflow">}>
// CHECK-SAME: !monad.either<[i32] throws {}>
// CHECK-SAME: !monad.either<[!monad.maybe<i32>] throws {#monad.error<"overflow">}>
func.func private @either_types(
    !monad.either<[i32] throws {#overflow_err}>,
    !monad.either<[i8, i32] throws {#monad.error<"div_by_zero">, #overflow_err}>,
    !monad.either<[] throws {#overflow_err}>,
    !monad.either<[i32] throws {}>,
    !monad.either<[!monad.maybe<i32>] throws {#overflow_err}>)

// The errors are a set: they are printed sorted by name, whatever their order
// in the input.
// CHECK-LABEL: func.func private @either_error_order
// CHECK-SAME: throws {#monad.error<"a">, #monad.error<"b">}
func.func private @either_error_order(
    !monad.either<[i32] throws {#monad.error<"b">, #monad.error<"a">}>)

// Wrap a value as a success of the either monad.
// CHECK-LABEL: func.func @either_return
// CHECK: monad.return %{{.*}} : !monad.either<[i32] throws {#monad.error<"overflow">}>
func.func @either_return(%value: i32) -> !monad.either<[i32] throws {#overflow_err}> {
  %result = monad.return %value : !monad.either<[i32] throws {#overflow_err}>
  return %result : !monad.either<[i32] throws {#overflow_err}>
}

// Bind an either value in a do with the same errors and other value types.
// CHECK: monad.do : !monad.either<[f32] throws {#monad.error<"overflow">}>
// CHECK: monad.bind %{{.*}}, ^[[NEXT:.+]] : !monad.either<[i32] throws {#monad.error<"overflow">}>
// CHECK: ^[[NEXT]](%{{.*}}: i32):
func.func @either_bind(%input: !monad.either<[i32] throws {#overflow_err}>)
    -> !monad.either<[f32] throws {#overflow_err}> {
  %result = monad.do : !monad.either<[f32] throws {#overflow_err}> {
    monad.bind %input, ^next : !monad.either<[i32] throws {#overflow_err}>
  ^next(%value: i32):
    %converted = arith.sitofp %value : i32 to f32
    %wrapped = monad.return %converted : !monad.either<[f32] throws {#overflow_err}>
    monad.yield %wrapped : !monad.either<[f32] throws {#overflow_err}>
  }
  return %result : !monad.either<[f32] throws {#overflow_err}>
}
