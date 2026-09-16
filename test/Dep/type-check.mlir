// RUN: fum-opt %s --dependent-type-check --split-input-file --verify-diagnostics --allow-unregistered-dialect

module attributes {dep.with_dependent_types} {
func.func private @direct_mismatch(%szA: i32, %szB: i32) {
  "dep.bind"(%szA, %szB) ({}, {}, {
    %szAB = arith.addi %szA, %szB: i32

    %a = "test.out_of_thin_air"() : () -> !dep.bitvector<"szA">
    %b = "test.out_of_thin_air"() : () -> !dep.bitvector<"szB">

    // expected-error @below {{failed to prove dependent type equivalence}}
    // expected-note @below {{function reduced to}}
    "dep.check_type_params_equal"() {
      lhs = !dep.bitvector<"szA">,
      rhs = !dep.bitvector<"szB">
    } : () -> ()

    // CHECK: dep.bind
    // CHECK: binds = {{\[}}[0, "szAB"]
    "dep.bind"(%szAB) ({}, {}, {
      // CHECK: dep.call
      %ab = "dep.call"(%szA, %szB, %szAB, %a, %b) {
        callee = @concat
      } : (i32, i32, i32, !dep.bitvector<"szA">, !dep.bitvector<"szB">)
        -> !dep.bitvector<"szAB">
      dep.yield
    })  {
      binds = [[0, "szAB"]]
    } : (i32) -> ()
    dep.yield
  })
  {
    binds = [[0, "szA"], [1, "szB"]]
  }
  : (i32, i32) -> ()
  return
}
}

// -----

module attributes {dep.with_dependent_types} {
func.func @dependent_type_outside_binder() {
  // expected-error @+1 {{dependent type used outside of the binder context}}
  %value = "test.out_of_thin_air"() : () -> !dep.bitvector<"size">
  return
}
}

// -----

module attributes {dep.with_dependent_types} {
// CHECK-LABEL: zero_is_folded_away
func.func private @zero_is_folded_away(%szA: i32, %szB: i32) {
  "dep.bind"(%szA, %szB) ({}, {}, {
    %szAB = arith.addi %szA, %szB: i32

    %a = "test.out_of_thin_air"() : () -> !dep.bitvector<"szA">
    %b = "test.out_of_thin_air"() : () -> !dep.bitvector<"szB">

    "dep.bind"(%szAB) ({}, {}, {
      %c = arith.constant 0 : i32
      %a_ = arith.addi %szA, %c : i32
      %szAB_ = arith.addi %a_, %szB : i32
      "dep.bind"(%szAB_) ({}, {}, {
        "dep.check_type_params_equal"() {
          lhs = !dep.bitvector<"szAB">,
          rhs = !dep.bitvector<"szAB_">
        } : () -> ()
        dep.yield
      }) {
        binds = [[0, "szAB_"]]
      } : (i32) -> ()
      dep.yield
    })  {
      binds = [[0, "szAB"]]
    } : (i32) -> ()
    dep.yield
  })
  {
    binds = [[0, "szA"], [1, "szB"]]
  }
  : (i32, i32) -> ()
  return
}
}

// -----

module attributes {dep.with_dependent_types} {
// CHECK-LABEL: cse_works
func.func private @cse_works(%szA: i32, %szB: i32) {
  "dep.bind"(%szA, %szB) ({}, {}, {
    %szAB = arith.addi %szA, %szB: i32

    %a = "test.out_of_thin_air"() : () -> !dep.bitvector<"szA">
    %b = "test.out_of_thin_air"() : () -> !dep.bitvector<"szB">

    "dep.bind"(%szAB) ({}, {}, {
      %szAB_ = arith.addi %szA, %szB : i32
      "dep.bind"(%szAB_) ({}, {}, {
        "dep.check_type_params_equal"() {
          lhs = !dep.bitvector<"szAB">,
          rhs = !dep.bitvector<"szAB_">
        } : () -> ()
        dep.yield
      }) {
        binds = [[0, "szAB_"]]
      } : (i32) -> ()
      dep.yield
    })  {
      binds = [[0, "szAB"]]
    } : (i32) -> ()
    dep.yield
  })
  {
    binds = [[0, "szA"], [1, "szB"]]
  }
  : (i32, i32) -> ()
  return
}
}

// -----

module attributes {dep.with_dependent_types} {
func.func private @off_by_one(%szA: i32, %szB: i32) {
  "dep.bind"(%szA, %szB) ({}, {}, {
    %szAB = arith.addi %szA, %szB: i32

    %a = "test.out_of_thin_air"() : () -> !dep.bitvector<"szA">
    %b = "test.out_of_thin_air"() : () -> !dep.bitvector<"szB">

    "dep.bind"(%szAB) ({}, {}, {
      %c = arith.constant 1 : i32
      %a_ = arith.addi %szA, %c : i32
      %szAB_ = arith.addi %a_, %szB : i32
      "dep.bind"(%szAB_) ({}, {}, {
        // expected-error @below {{failed to prove dependent type equivalence}}
        // expected-note @below {{function reduced to}}
        "dep.check_type_params_equal"() {
          lhs = !dep.bitvector<"szAB">,
          rhs = !dep.bitvector<"szAB_">
        } : () -> ()
        dep.yield
      }) {
        binds = [[0, "szAB_"]]
      } : (i32) -> ()
      dep.yield
    })  {
      binds = [[0, "szAB"]]
    } : (i32) -> ()
    dep.yield
  })
  {
    binds = [[0, "szA"], [1, "szB"]]
  }
  : (i32, i32) -> ()
  return
}
}
