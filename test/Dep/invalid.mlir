// RUN: fum-opt %s --split-input-file --verify-diagnostics --allow-unregistered-dialect

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects 'binds' to be an array of size-two arrays}}
"dep.func"() ({}, {}, {}) {
    sym_name = "wrong_bind_structure",
    function_type = () -> (),
    sym_visibility = "private",
    binds = [[]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects the first entry of each pair in 'binds' to be an integer, got "foo"}}
"dep.func"() ({}, {}, {}) {
    sym_name = "wrong_bind_attr_kind",
    function_type = () -> (),
    sym_visibility = "private",
    binds = [["foo", "bar"]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{binder position 0 is out of bounds, the op only binds 0 values to parameters}}
"dep.func"() ({}, {}, {}) {
    sym_name = "bind_out_of_bounds",
    function_type = () -> (),
    sym_visibility = "private",
    binds = [[0, "foo"]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{value bound to dependent type parameter '"foo"' has type 'f32' not allowed as dependent type parameter}}
"dep.func"() ({}, {}, {}) {
    sym_name = "wrong_bind_type",
    function_type = (f32) -> (),
    sym_visibility = "private",
    binds = [[0, "foo"]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects the second entry of each pair in 'binds' to be a string, got 1}}
"dep.func"() ({}, {}, {}) {
    sym_name = "wrong_bind_attr_kind_2",
    function_type = (i32) -> (),
    sym_visibility = "private",
    binds = [[0, 1]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects the 'body' region to have the same number of arguments as the function signature}}
"dep.func"() ({}, {}, {
^bb2:
  dep.yield
}) {
    sym_name = "mismatch_arg",
    function_type = (i32) -> (),
    sym_visibility = "private",
    binds = [[0, "foo"]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects 'body' region argument types to match function signature, mismatch at position 0, 'f32' vs 'i32'}}
"dep.func"() ({}, {}, {
^bb2(%arg2: f32):
  dep.yield
}) {
    sym_name = "mismatch_arg",
    function_type = (i32) -> (),
    sym_visibility = "private",
    binds = [[0, "foo"]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects the 'ensures' region to have as many arguments as bound dependent type parameters, got 0 vs 1}}
"dep.func"() ({}, {
^bb2:
  dep.yield
}, {}) {
    sym_name = "mismatch_arg",
    function_type = (i32) -> (),
    sym_visibility = "private",
    binds = [[0, "foo"]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects 'ensures' region argument types to match the bound dependent type parameters in order, mismatch at position 0, 'f32' vs 'i32'}}
"dep.func"() ({}, {
^bb2(%arg2: f32):
  dep.yield
}, {}) {
    sym_name = "mismatch_arg",
    function_type = (i32) -> (),
    sym_visibility = "private",
    binds = [[0, "foo"]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects the 'requires' region to have as many arguments as bound dependent type parameters, got 0 vs 1}}
"dep.func"() ({
^bb2:
  dep.yield
}, {}, {}) {
    sym_name = "mismatch_arg",
    function_type = (i32) -> (),
    sym_visibility = "private",
    binds = [[0, "foo"]]
} : () -> ()
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects 'requires' region argument types to match the bound dependent type parameters in order, mismatch at position 0, 'f32' vs 'i32'}}
"dep.func"() ({
^bb2(%arg2: f32):
  dep.yield
}, {}, {}) {
    sym_name = "mismatch_arg",
    function_type = (i32) -> (),
    sym_visibility = "private",
    binds = [[0, "foo"]]
} : () -> ()
}

// -----

"dep.func"() ({}, {}, {
    // expected-error @below {{dependent type '!dep.bitvector<"dep">' uses type parameter "dep" not bound to a value}}
    "op.foo"() : () -> (!dep.bitvector<"dep">)
    dep.yield
}) {
    sym_name = "undefined_dep_param",
    function_type = () -> (),
    sym_visibility = "private",
    binds = []
} : () -> ()

// -----

"dep.func"() ({}, {}, {
    "op.foo"()({
    ^bb0:
      dep.yield
    // expected-error @below {{dependent type '!dep.bitvector<"dep">' uses type parameter "dep" not bound to a value}}
    ^bb1(%arg: !dep.bitvector<"dep">):
      dep.yield
    }) : () -> ()
    dep.yield
}) {
    sym_name = "undefined_dep_param",
    function_type = () -> (),
    sym_visibility = "private",
    binds = []
} : () -> ()

// -----

"dep.func"() ({}, {}, {
    // expected-error @below {{dependent type '!dep.bitvector<"dep">' uses type parameter "dep" not bound to a value}}
    "op.foo"() { bar = !dep.bitvector<"dep">} : () -> ()
    dep.yield
}) {
    sym_name = "undefined_dep_param",
    function_type = () -> (),
    sym_visibility = "private",
    binds = []
} : () -> ()


// -----

"dep.func"() ({}, {}, {
    // expected-error @below {{dependent type '!dep.bitvector<"dep">' uses type parameter "dep" not bound to a value}}
    "op.foo"() { bar = [1, [2, !dep.bitvector<"dep">]]} : () -> ()
    dep.yield
}) {
    sym_name = "undefined_dep_param",
    function_type = () -> (),
    sym_visibility = "private",
    binds = []
} : () -> ()

// -----

module attributes {dep.with_dependent_types} {
dep.func @unknown_binding(%value: i32)
binds {
  // expected-error @below {{attempting to bind a value that is not a function argument}}
  %missing -> "missing"
}
}

// -----

module attributes {dep.with_dependent_types} {
dep.func @wrong_yield_count(%value: i32) -> i32
binds {
}
{
  // expected-error @below {{expects the number of yielded values to match function signature, got 0 vs 1}}
  dep.yield
}
}

// -----

module attributes {dep.with_dependent_types} {
dep.func @wrong_yield_type(%value: i32) -> i64
binds {
}
{
  // expected-error @below {{expects yielded value types to match function signature, mismatch at position 0, 'i32' vs 'i64'}}
  dep.yield %value : i32
}
}

// -----

func.func @wrong_bind_yield_count(%value: i32) {
  %result = dep.bind (%value: i32) -> i32
  binds {
  }
  {
    // expected-error @below {{expects the number of yielded values to match dep.bind result types, got 0 vs 1}}
    dep.yield
  }
  return
}

// -----

func.func @wrong_bind_yield_type(%value: i32) {
  %result = dep.bind (%value: i32) -> i64
  binds {
  }
  {
    // expected-error @below {{expects yielded value types to match dep.bind result types, mismatch at position 0, 'i32' vs 'i64'}}
    dep.yield %value : i32
  }
  return
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects 'requires' region blocks to be terminated with dep.yield}}
dep.func @requires_without_yield()
binds {
}
requires {
  "test.not_yield"() : () -> ()
}
}

// -----

module attributes {dep.with_dependent_types} {
// expected-error @below {{expects 'requires' region blocks to yield a single i1 value}}
dep.func @requires_yielding_i32()
binds {
}
requires {
  %zero = arith.constant 0 : i32
  dep.yield %zero : i32
}
}

// -----

func.func @unknown_bind_operand(%value: i32) {
  dep.bind (%value: i32)
  binds {
    // expected-error @below {{attempting to bind a value that is not an operand}}
    %missing -> "missing"
  }
  return
}

// -----

dep.type.constructor @mismatched_product_names()
binds {
}
{
  %value = dep.type i32
  // expected-error @below {{expects 'names' to have 1 entries, but got 2}}
  %product = "dep.type.product"(%value) {names = ["first", "second"]}
      : (!dep.type) -> !dep.type
  dep.yield %product : !dep.type
}

// -----

// expected-error @below {{expects 'requires' region blocks to yield a single i1 value}}
dep.type.constructor @bad_requires(%N: i32)
binds {
  %N -> "N"
}
requires {
^bb0(%N: i32):
  %value = arith.constant 0 : i32
  dep.yield %value : i32
}
{
  %value = dep.type i32
  dep.yield %value : !dep.type
}

// -----

// expected-error @below {{expects the 'body' region to yield a single !dep.type value}}
dep.type.constructor @bad_body_yield(%N: i32)
binds {
}
requires {
  %okay = arith.constant true
  dep.yield %okay : i1
}
{
  dep.yield %N : i32
}

// -----

// expected-error @below {{expects 'body' region to contain only pure operations}}
dep.type.constructor @impure_body(%N: i32)
binds {
}
requires {
  %okay = arith.constant true
  dep.yield %okay : i1
}
{
  "test.not_pure"() : () -> ()
  %value = dep.type i32
  dep.yield %value : !dep.type
}

// -----

// expected-error @below {{expects 'body' region to contain only pure operations}}
dep.type.constructor @impure_nested_bind()
binds {
}
{
  %bound = dep.bind () -> !dep.type
  binds {
  }
  {
    "test.not_pure"() : () -> ()
    %value = dep.type i32
    dep.yield %value : !dep.type
  }
  dep.yield %bound : !dep.type
}

// -----

func.func @type_outside_constructor() {
  // expected-error @below {{must appear inside a dep.type.constructor operation}}
  %value = dep.type i32
  return
}

// -----

func.func @type_sum_outside_constructor() {
  %element = "test.type"() : () -> !dep.type
  // expected-error @below {{must appear inside a dep.type.constructor operation}}
  %sum = dep.type.sum %element
  return
}

// -----

func.func @type_product_outside_constructor() {
  %element = "test.type"() : () -> !dep.type
  // expected-error @below {{must appear inside a dep.type.constructor operation}}
  %product = dep.type.product %element
  return
}

// -----

func.func @invalid_constructed_type_parameters() {
  // expected-error @below {{expected constructed type parameters to be string attributes}}
  "test.make"() : () -> !dep.constructed<@Float("N", 1)>
  return
}

// -----

dep.type.constructor @undefined_type_constructor()
binds {
}
{
  // expected-error @below {{dependent type '!dep.constructed<@Missing()>' references undefined symbol @Missing}}
  %value = dep.type !dep.constructed<@Missing()>
  dep.yield %value : !dep.type
}

// -----

dep.type.constructor @sum_duplicate_names()
binds {
}
{
  %none = dep.type none
  // expected-error @below {{expects distinct case names, got 'a_err' twice}}
  %sum = dep.type.sum {
    "a_err": %none,
    "a_err": %none
  }
  dep.yield %sum : !dep.type
}

// -----

dep.type.constructor @sum_names_mismatch()
binds {
}
{
  %none = dep.type none
  // expected-error @below {{expects 'names' to have 1 entries, but got 2}}
  %sum = "dep.type.sum"(%none) {names = ["a_err", "b_err"]} : (!dep.type) -> !dep.type
  dep.yield %sum : !dep.type
}

// -----

// expected-error @below {{expects at least one case}}
func.func private @sum_empty(!dep.sum<>)

// -----

// expected-error @below {{expected a case name}}
func.func private @sum_unnamed(!dep.sum<(i32)>)

// -----

// expected-error @below {{expects distinct case names, got 'a' twice}}
func.func private @sum_duplicate(!dep.sum<a, a(i32)>)

// -----

func.func @sum_make_unknown_case() {
  // expected-error @below {{expects 'c' to be a case of '!dep.sum<a, b>'}}
  %c = dep.sum.make c : !dep.sum<a, b>
  return
}

// -----

func.func @sum_make_wrong_fields(%x: i64) {
  // expected-error @below {{expects the fields of case 'a' to have types ('i32')}}
  %a = "dep.sum.make"(%x) {case_name = "a"} : (i64) -> !dep.sum<a(i32)>
  return
}

// -----

func.func @sum_switch_not_exhaustive(%s: !dep.sum<a, b>) {
  // expected-error @below {{expects every case to be listed, or a default case}}
  dep.sum.switch %s : !dep.sum<a, b>, [
    a: ^a
  ]
^a:
  return
}

// -----

func.func @sum_switch_useless_default(%s: !dep.sum<a>) {
  // expected-error @below {{expects the default case to handle at least one case}}
  dep.sum.switch %s : !dep.sum<a>, [
    default: ^a,
    a: ^a
  ]
^a:
  return
}

// -----

func.func @sum_switch_wrong_fields(%s: !dep.sum<a(i32)>) {
  // expected-error @below {{expects the successor of case 'a' to take arguments of types ('i32')}}
  dep.sum.switch %s : !dep.sum<a(i32)>, [
    a: ^a
  ]
^a(%x: i64):
  return
}
