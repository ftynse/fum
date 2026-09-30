// RUN: fum-opt %s | fum-opt | FileCheck %s

// Round-trip a definition with bindings, auxiliary regions, and a body.
// CHECK-LABEL: dep.func private @with_body
// CHECK-SAME: (%[[ARG0:.+]]: i32) -> i32
// CHECK: binds {
// CHECK-NEXT: %[[ARG0]] -> "n"
// CHECK-NEXT: }
// CHECK-NEXT: requires {
// CHECK-NEXT: ^{{.*}}(%{{.*}}: i32):
// CHECK: dep.yield
// CHECK-NEXT: }
// CHECK-NEXT: ensures {
// CHECK-NEXT: ^{{.*}}(%{{.*}}: i32):
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
// CHECK-NEXT: ^{{.*}}(%{{.*}}: i32):
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
// CHECK-NEXT: ^{{.*}}(%{{.*}}: i32, %{{.*}}: i1):
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
// CHECK-NEXT: ^{{.*}}(%{{.*}}: i32):
// CHECK: dep.yield
// CHECK-NEXT: }
// CHECK: ^{{.*}}(%{{.*}}: i32):
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
// CHECK-NEXT: ^{{.*}}(%{{.*}}: i32, %{{.*}}: i1):
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

// Named product elements use the field-name syntax and are reconstructed as
// the `names` attribute by the custom parser.
// CHECK-LABEL: dep.type.constructor @named_product
// CHECK: %[[EXPONENT:.+]] = dep.type i32
// CHECK: %[[MANTISSA:.+]] = dep.type i64
// CHECK: %[[PRODUCT:.+]] = dep.type.product {
// CHECK-NEXT: "exponent": %[[EXPONENT]],
// CHECK-NEXT: "mantissa": %[[MANTISSA]]
// CHECK-NEXT: }
dep.type.constructor @named_product()
binds {
}
{
  %exponent = dep.type i32
  %mantissa = dep.type i64
  %product = dep.type.product {
    "exponent": %exponent,
    "mantissa": %mantissa
  }
  dep.yield %product : !dep.type
}

// Unnamed products use a comma-separated operand list, and arbitrary operation
// attributes remain outside the custom element list.
// CHECK-LABEL: dep.type.constructor @unnamed_product
// CHECK: %[[FIRST:.+]] = dep.type i1
// CHECK: %[[SECOND:.+]] = dep.type i8
// CHECK: %{{.*}} = dep.type.product %[[FIRST]], %[[SECOND]] attributes {test = "kept"}
dep.type.constructor @unnamed_product()
binds {
}
{
  %first = dep.type i1
  %second = dep.type i8
  %product = dep.type.product %first, %second attributes {test = "kept"}
  dep.yield %product : !dep.type
}

// Round-trip a type constructor with implicit signature arguments in both
// regions and a body yielding a dependent type.
// CHECK-LABEL: dep.type.constructor @Float
// CHECK-SAME: (%[[N:.+]]: i32, %[[E:.+]]: i32, %[[NE1:.+]]: i32)
// CHECK: binds {
// CHECK-NEXT: %[[N]] -> "N",
// CHECK-NEXT: %[[E]] -> "E",
// CHECK-NEXT: %[[NE1]] -> "NE1"
// CHECK-NEXT: }
// CHECK: requires {
// CHECK-NEXT: ^{{.*}}(%{{.*}}: i32, %{{.*}}: i32, %{{.*}}: i32):
// CHECK-NEXT: %{{.*}} = arith.constant true
// CHECK-NEXT: dep.yield %{{.*}} : i1
// CHECK-NEXT: }
// CHECK: {
// CHECK: %{{.*}} = dep.type !dep.constructed<@Float("N", "E", "NE1")>
// CHECK: dep.yield %{{.*}} : !dep.type
// CHECK-NEXT: }
dep.type.constructor @Float(%N: i32, %E: i32, %NE1: i32)
binds {
  %N -> "N",
  %E -> "E",
  %NE1 -> "NE1"
}
requires {
^bb0(%N: i32, %E: i32, %NE1: i32):
  %okay = arith.constant true
  dep.yield %okay : i1
}
{
  %float = dep.type !dep.constructed<@Float("N", "E", "NE1")>
  dep.yield %float : !dep.type
}

// A dep.bind is allowed in a type constructor when all operations nested in
// it are pure.
// CHECK-LABEL: dep.type.constructor @bind_in_body
// CHECK: %[[BOUND:.+]] = dep.bind () -> !dep.type
// CHECK: %[[TYPE:.+]] = dep.type i32
// CHECK: dep.yield %[[TYPE]] : !dep.type
// CHECK: dep.yield %[[BOUND]] : !dep.type
dep.type.constructor @bind_in_body()
binds {
}
{
  %bound = dep.bind () -> !dep.type
  binds {
  }
  {
    %type = dep.type i32
    dep.yield %type : !dep.type
  }
  dep.yield %bound : !dep.type
}

// We only care that this is accepted, no need for syntax check.
// dep.type.constructor @Float2
dep.type.constructor @Float2(%N: i32, %E: i32)
binds {
  %N -> "N",
  %E -> "E"
}
requires {
^bb0(%N: i32, %E: i32):
  %c0 = arith.constant 0 : i32
  %N_non_negative = arith.cmpi sge, %N, %c0 : i32

  %E_non_negative = arith.cmpi sge, %E, %c0 : i32
  %E_less_than_N = arith.cmpi slt, %E, %N: i32
  %E_okay = arith.andi %E_non_negative, %E_less_than_N : i1

  %okay = arith.andi %N_non_negative, %E_okay : i1
  dep.yield %okay : i1
}
{
  %c1 = arith.constant 1 : i32
  %N_minus_E = arith.subi %N, %E : i32
  %N_minus_E_minus_one = arith.subi %N_minus_E, %c1 : i32
  %t = dep.bind (%c1: i32, %N_minus_E_minus_one: i32) -> !dep.type
  binds {
    %c1 -> "one",
    %N_minus_E_minus_one -> "NE1"
  }
  {
    %bits_N = dep.type !dep.bitvector<"N">
    %bits_NE1 = dep.type !dep.bitvector<"NE1">
    %bits_1 = dep.type !dep.bitvector<"one">
    %i1 = dep.type i1
    %type = dep.type.product {
        "exponent": %bits_N,
        "mantissa": %bits_NE1,
        "sign": %bits_1,
        "is_inf": %i1
    }
    dep.yield %type : !dep.type
  }
  dep.yield %t : !dep.type
}
