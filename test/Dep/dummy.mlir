// RUN: fum-opt -allow-unregistered-dialect %s | fum-opt -allow-unregistered-dialect | FileCheck %s --check-prefix=NEW

module attributes {dep.with_dependent_types} {
// CHECK: dep.func
// CHECK: binds = {{\[}}[0, "szA"], [1, "szB"], [2, "szAB"]]
// CHECK: function_type = (i32, i32, i32, !dep.bitvector<"szA">, !dep.bitvector<"szB">) -> !dep.bitvector<"szAB">
// NEW: dep.func private @concat(%arg0: i32, %arg1: i32, %arg2: i32, %arg3: !dep.bitvector<"szA">, %arg4: !dep.bitvector<"szB">) -> !dep.bitvector<"szAB">
// NEW: binds {
// NEW-NEXT: %arg0 -> "szA",
// NEW-NEXT: %arg1 -> "szB",
// NEW-NEXT: %arg2 -> "szAB"
// NEW-NEXT: }
"dep.func"() ({
^bb0(%szA: i32, %szB: i32, %szAB: i32):
  %szAB_ = arith.addi %szA, %szB : i32
  %eq = arith.cmpi eq, %szAB_, %szAB : i32
  // CHECK: dep.yield
  dep.yield %eq : i1
}, {
}, {
^bb0(%szA: i32, %szB: i32, %szAB: i32, %A: !dep.bitvector<"szA">, %B: !dep.bitvector<"szB">):
  // TODO: (zeros of szAB) BIT_OR (A lsh szB) BIT_OR B
  %out = "test.out_of_thin_air"() : () -> !dep.bitvector<"szAB">
  dep.yield %out : !dep.bitvector<"szAB">
})
{
    sym_name = "concat",
    function_type = (i32, i32, i32, !dep.bitvector<"szA">, !dep.bitvector<"szB">)
                  -> !dep.bitvector<"szAB">,
    sym_visibility = "private",
    binds = [[0, "szA"], [1, "szB"], [2, "szAB"]]
}
: () -> ()

func.func private @bar(%szA: i32) {
  %szAA = arith.addi %szA, %szA : i32
  // %c2 = arith.constant 2 : i32
  // %sz2A = arith.muli %c2, %szA : i32
  %sz2A = arith.addi %szA, %szA : i32
  // CHECK: dep.bind
  "dep.bind"(%szAA, %sz2A) ({}, {}, {
    "dep.check_type_params_equal"() {
      lhs = !dep.bitvector<"szAA">,
      rhs = !dep.bitvector<"sz2A">
    } : () -> ()
    dep.yield
  })
  {
    binds = [[0, "szAA"], [1, "sz2A"]]
  } : (i32, i32) -> ()
  return
}

func.func private @foo(%szA: i32, %szB: i32) {
  "dep.bind"(%szA, %szB) ({}, {}, {
    %szAB = arith.addi %szA, %szB: i32

    %a = "test.out_of_thin_air"() : () -> !dep.bitvector<"szA">
    %b = "test.out_of_thin_air"() : () -> !dep.bitvector<"szB">

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
