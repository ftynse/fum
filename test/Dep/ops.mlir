// RUN: fum-opt %s | fum-opt | FileCheck %s

// Round-trip a definition with bindings, auxiliary regions, and a body.
// CHECK-LABEL: dep.func private @with_body
// CHECK-SAME: (%[[ARG0:.+]]: i32) -> i32
// CHECK: binds {
// CHECK-NEXT: %[[ARG0]] -> "n"
// CHECK-NEXT: }
// CHECK-NEXT: requires {
// CHECK-NEXT: ^bb0(%{{.*}}: i32):
// CHECK: dep.yield
// CHECK-NEXT: }
// CHECK-NEXT: ensures {
// CHECK-NEXT: ^bb0(%{{.*}}: i32):
// CHECK: dep.yield
// CHECK-NEXT: }
// CHECK: dep.yield
dep.func private @with_body(%n: i32) -> i32
binds {
  %n -> "n"
}
requires {
^bb0(%n: i32):
  %predicate = arith.constant true
  dep.yield %predicate : i1
}
ensures {
^bb0(%n: i32):
  %predicate = arith.constant true
  dep.yield %predicate : i1
}
{
  dep.yield %n : i32
}

// Round-trip a declaration with no body. Its synthetic argument name must
// remain usable in the printed binding list. Note that we intentionally
// check the SSA value name here because our printer/parser emits these
// for declarations as opposed to the generic printer/parser.
// CHECK-LABEL: dep.func @declaration
// CHECK-SAME: (%arg0: i64)
// CHECK: binds {
// CHECK-NEXT: %arg0 -> "extent"
// CHECK-NEXT: }
dep.func @declaration(%extent: i64)
binds {
  %extent -> "extent"
}

// Round-trip a function with only a requires region.
// CHECK-LABEL: dep.func @requires_only
// CHECK-SAME: (%[[REQUIRES_ARG:.+]]: i32)
// CHECK: binds {
// CHECK-NEXT: %[[REQUIRES_ARG]] -> "size"
// CHECK-NEXT: }
// CHECK-NEXT: requires {
// CHECK-NEXT: ^bb0(%{{.*}}: i32):
// CHECK: dep.yield
dep.func @requires_only(%size: i32)
binds {
  %size -> "size"
}
requires {
^bb0(%size: i32):
  %predicate = arith.constant true
  dep.yield %predicate : i1
}

// Bind the first and third function arguments while leaving the middle
// argument unbound.
// CHECK-LABEL: dep.func @non_consecutive_func_bindings
// CHECK-SAME: (%[[FUNC_FIRST:.+]]: i32, %{{.*}}: i64, %[[FUNC_THIRD:.+]]: i1)
// CHECK: binds {
// CHECK-NEXT: %[[FUNC_FIRST]] -> "first",
// CHECK-NEXT: %[[FUNC_THIRD]] -> "third"
// CHECK-NEXT: }
// CHECK-NEXT: requires {
// CHECK-NEXT: ^bb0(%{{.*}}: i32, %{{.*}}: i1):
// CHECK: dep.yield
dep.func @non_consecutive_func_bindings(
    %first: i32, %middle: i64, %third: i1)
binds {
  %first -> "first",
  %third -> "third"
}
requires {
^bb0(%bound_first: i32, %bound_third: i1):
  dep.yield %bound_third : i1
}

// Round-trip a function with only an ensures region and no bindings.
// CHECK-LABEL: dep.func @ensures_only()
// CHECK: binds {
// CHECK-NEXT: }
// CHECK-NEXT: ensures {
// CHECK: dep.yield
// CHECK-NEXT: }
dep.func @ensures_only()
binds {
}
ensures {
  %predicate = arith.constant true
  dep.yield %predicate : i1
}

// Preserve user attributes while printing the custom syntax.
// CHECK-LABEL: dep.func @with_attributes
// CHECK-SAME: (%{{.*}}: i32) -> i32
// CHECK: attributes {test = "kept"}
// CHECK: binds {
// CHECK-NEXT: }
// CHECK: dep.yield
dep.func @with_attributes(%value: i32) -> i32 attributes {test = "kept"}
binds {
}
{
  dep.yield %value : i32
}

// Round-trip inline bindings. Unlike dep.func, bindings resolve to operands
// and the body block owns its own arguments.
// CHECK-LABEL: func.func @bind_cases
// CHECK: dep.bind (%{{.*}}: i32, %{{.*}}: i64) -> i32
// CHECK: attributes {test = "bind"}
// CHECK: binds {
// CHECK-NEXT: %{{.*}} -> "size"
// CHECK-NEXT: }
// CHECK-NEXT: requires {
// CHECK-NEXT: ^bb0(%{{.*}}: i32):
// CHECK: dep.yield
// CHECK-NEXT: }
// CHECK: ^bb0(%{{.*}}: i32):
// CHECK: dep.yield
// CHECK: dep.bind ()
// CHECK: binds {
// CHECK-NEXT: }
// CHECK-NEXT: ensures {
// CHECK: dep.yield
// CHECK-NEXT: }
func.func @bind_cases(%size: i32, %offset: i64) {
  %bound = dep.bind (%size: i32, %offset: i64) -> i32 attributes {test = "bind"}
  binds {
    %size -> "size"
  }
  requires {
  ^bb0(%bound_size: i32):
    %predicate = arith.constant true
    dep.yield %predicate : i1
  }
  {
  ^bb0(%body_value: i32):
    dep.yield %body_value : i32
  }

  dep.bind ()
  binds {
  }
  ensures {
    %predicate = arith.constant true
    dep.yield %predicate : i1
  }
  return
}

// Bind the first and third operands while leaving the middle operand unbound.
// CHECK-LABEL: func.func @non_consecutive_bindings
// CHECK: dep.bind (%[[FIRST:.+]]: i32, %{{.*}}: i64, %[[THIRD:.+]]: i1)
// CHECK: binds {
// CHECK-NEXT: %[[FIRST]] -> "first",
// CHECK-NEXT: %[[THIRD]] -> "third"
// CHECK-NEXT: }
// CHECK-NEXT: requires {
// CHECK-NEXT: ^bb0(%{{.*}}: i32, %{{.*}}: i1):
// CHECK: dep.yield
func.func @non_consecutive_bindings(%first: i32, %middle: i64, %third: i1) {
  dep.bind (%first: i32, %middle: i64, %third: i1)
  binds {
    %first -> "first",
    %third -> "third"
  }
  requires {
  ^bb0(%bound_first: i32, %bound_third: i1):
    dep.yield %bound_third : i1
  }
  return
}
