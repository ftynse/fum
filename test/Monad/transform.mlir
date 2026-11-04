// RUN: fum-opt %s | fum-opt | FileCheck %s

// The transform script of the Transform dialect tutorial
// (mlir/test/Examples/transform/Ch1/sequence.mlir) written with the maybe
// monad. Each transform operation returns its handles in one maybe value,
// which fails if the operation fails.

!any = !transform.any_op
!handles = !monad.maybe<!any, !any>
!outlined = !monad.maybe<!any, !transform.op<"func.call">>

// Models of the transform operations used by the script.
func.func private @split_handle(!transform.op<"linalg.elementwise">) -> !handles
func.func private @tile_using_forall(!any) -> !handles
func.func private @fuse_into_containing_op(!any, !any) -> !handles
func.func private @loop_outline(!any) -> !outlined

// CHECK-LABEL: func.func @__transform_main
// CHECK: monad.do : !monad.maybe<!transform.any_op, !transform.op<"func.call">>
// CHECK: call @split_handle
// CHECK: call @tile_using_forall(%{{.*}}) {tile_sizes = array<i64: 8, 32>}
// CHECK: call @fuse_into_containing_op
// CHECK: transform.cast %{{.*}} : !transform.op<"linalg.matmul"> to !transform.any_op
// CHECK: call @fuse_into_containing_op
// CHECK: call @tile_using_forall(%{{.*}}) {tile_sizes = array<i64: 4, 4>}
// CHECK: call @fuse_into_containing_op
// CHECK: call @tile_using_forall(%{{.*}}) {tile_sizes = array<i64: 1>}
// CHECK: call @fuse_into_containing_op
// CHECK: %[[OUTLINED:.+]] = func.call @loop_outline(%{{.*}}) {func_name = "outlined"}
// CHECK: monad.yield %[[OUTLINED]]
func.func @__transform_main(%arg0: !any,
                            %arg1: !transform.op<"linalg.matmul">,
                            %arg2: !transform.op<"linalg.elementwise">)
    -> !outlined {
  %result = monad.do : !outlined {
    // %add, %max = transform.split_handle %arg2
    %split = func.call @split_handle(%arg2)
        : (!transform.op<"linalg.elementwise">) -> !handles
    monad.bind %split, ^split : !handles
  ^split(%add: !any, %max: !any):
    // %tiled, %loop = transform.structured.tile_using_forall %max
    //     tile_sizes [8, 32]
    %tile = func.call @tile_using_forall(%max) {tile_sizes = array<i64: 8, 32>}
        : (!any) -> !handles
    monad.bind %tile, ^tiled : !handles
  ^tiled(%tiled: !any, %loop: !any):
    // %add_fused, %loop2 = transform.structured.fuse_into_containing_op
    //     %add into %loop
    %fuse_add = func.call @fuse_into_containing_op(%add, %loop)
        : (!any, !any) -> !handles
    monad.bind %fuse_add, ^fused_add : !handles
  ^fused_add(%add_fused: !any, %loop2: !any):
    // %matmul_fused, %loop3 = transform.structured.fuse_into_containing_op
    //     %arg1 into %loop2
    %matmul = transform.cast %arg1 : !transform.op<"linalg.matmul"> to !any
    %fuse_matmul = func.call @fuse_into_containing_op(%matmul, %loop2)
        : (!any, !any) -> !handles
    monad.bind %fuse_matmul, ^fused_matmul : !handles
  ^fused_matmul(%matmul_fused: !any, %loop3: !any):
    // %tiled_second, %loop_second =
    //     transform.structured.tile_using_forall %add_fused tile_sizes [4, 4]
    %tile_second = func.call @tile_using_forall(%add_fused)
        {tile_sizes = array<i64: 4, 4>} : (!any) -> !handles
    monad.bind %tile_second, ^tiled_second : !handles
  ^tiled_second(%tiled_second: !any, %loop_second: !any):
    // %matmul_fused_2, %loop_second_2 =
    //     transform.structured.fuse_into_containing_op
    //     %matmul_fused into %loop_second
    %fuse_second = func.call @fuse_into_containing_op(%matmul_fused,
                                                      %loop_second)
        : (!any, !any) -> !handles
    monad.bind %fuse_second, ^fused_second : !handles
  ^fused_second(%matmul_fused_2: !any, %loop_second_2: !any):
    // %_0, %loop_third = transform.structured.tile_using_forall
    //     %tiled_second tile_sizes [1]
    %tile_third = func.call @tile_using_forall(%tiled_second)
        {tile_sizes = array<i64: 1>} : (!any) -> !handles
    monad.bind %tile_third, ^tiled_third : !handles
  ^tiled_third(%_0: !any, %loop_third: !any):
    // %_1, %outline_target = transform.structured.fuse_into_containing_op
    //     %matmul_fused_2 into %loop_third
    %fuse_third = func.call @fuse_into_containing_op(%matmul_fused_2,
                                                     %loop_third)
        : (!any, !any) -> !handles
    monad.bind %fuse_third, ^fused_third : !handles
  ^fused_third(%_1: !any, %outline_target: !any):
    // %func, %call = transform.loop.outline %outline_target
    //     func_name = "outlined"
    %outlined = func.call @loop_outline(%outline_target)
        {func_name = "outlined"} : (!any) -> !outlined
    monad.yield %outlined : !outlined
  }
  return %result : !outlined
}
