// RUN: fum-opt %s | fum-opt | FileCheck %s
// RUN: fum-opt %s --mlir-print-op-generic | fum-opt | FileCheck %s

// Cases may be written in any order; they are printed sorted by name.
// CHECK-LABEL: func.func private @types
// CHECK-SAME: !adt.sum<a>, !adt.sum<a, b(i32, f32)>
func.func private @types(!adt.sum<a>, !adt.sum<b(i32, f32), a>)

// CHECK-LABEL: func.func @make
// CHECK: adt.make a : !adt.sum<a, b(i32)>
// CHECK: adt.make b(%{{.*}}) : !adt.sum<a, b(i32)>
func.func @make(%x: i32) -> (!adt.sum<a, b(i32)>, !adt.sum<a, b(i32)>) {
  %a = adt.make a : !adt.sum<a, b(i32)>
  %b = adt.make b(%x) : !adt.sum<a, b(i32)>
  return %a, %b : !adt.sum<a, b(i32)>, !adt.sum<a, b(i32)>
}

// CHECK-LABEL: func.func @switch
// CHECK: adt.switch %{{.*}} : !adt.sum<a, b(i32), c>, [
// CHECK-NEXT: default: ^[[OTHER:.*]],
// CHECK-NEXT: b: ^[[B:.*]]
// CHECK-NEXT: ]
// CHECK: ^[[B]](%{{.*}}: i32):
// CHECK: ^[[OTHER]]:
func.func @switch(%s: !adt.sum<a, b(i32), c>) -> i32 {
  adt.switch %s : !adt.sum<a, b(i32), c>, [
    default: ^other,
    b: ^b
  ]
^b(%x: i32):
  return %x : i32
^other:
  %zero = arith.constant 0 : i32
  return %zero : i32
}
