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
  // expected-error @+1 {{attempting to bind a value that is not a function argument}}
  %missing -> "missing"
}
}

// -----

module attributes {dep.with_dependent_types} {
dep.func @wrong_yield_count(%value: i32) -> i32
binds {
}
{
  // expected-error @+1 {{expects the number of yielded values to match function signature, got 0 vs 1}}
  dep.yield
}
}

// -----

module attributes {dep.with_dependent_types} {
dep.func @wrong_yield_type(%value: i32) -> i64
binds {
}
{
  // expected-error @+1 {{expects yielded value types to match function signature, mismatch at position 0, 'i32' vs 'i64'}}
  dep.yield %value : i32
}
}

// -----

func.func @wrong_bind_yield_count(%value: i32) {
  %result = dep.bind (%value: i32) -> i32
  binds {
  }
  {
    // expected-error @+1 {{expects the number of yielded values to match dep.bind result types, got 0 vs 1}}
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
    // expected-error @+1 {{expects yielded value types to match dep.bind result types, mismatch at position 0, 'i32' vs 'i64'}}
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
    // expected-error @+1 {{attempting to bind a value that is not an operand}}
    %missing -> "missing"
  }
  return
}
