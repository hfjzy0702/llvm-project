// RUN: mlir-opt %s -convert-linalg-to-loops -convert-linalg-to-llvm -convert-std-to-llvm | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

// RUN: mlir-opt %s -linalg-tile="linalg-tile-sizes=0,0,5,5,5" -convert-linalg-to-loops \
// RUN:   -convert-linalg-to-llvm -convert-std-to-llvm | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

// RUN: mlir-opt %s -linalg-tile="linalg-tile-sizes=1,1,1,1,1" -test-conv-vectorization \
// RUN:   -convert-linalg-to-loops -test-vector-contraction-conversion=vector-outerproduct=0 \
// RUN:   -convert-vector-to-scf -convert-linalg-to-llvm | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

// RUN: mlir-opt %s -linalg-tile="linalg-tile-sizes=0,0,5,5,5" -linalg-tile="linalg-tile-sizes=1,1,1,1,1" \
// RUN:   -test-conv-vectorization -convert-linalg-to-loops \
// RUN:   -test-vector-contraction-conversion=vector-outerproduct=0 \
// RUN:   -convert-vector-to-scf -convert-linalg-to-llvm | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

func @print_memref_f32(memref<*xf32>)

// Creates and returns 5-D buffer of size (%s1, %s2, %s3, %s4, %s5) filled with the value %f
func @alloc_5d_filled_f32(%s1 : index, %s2 : index, %s3 : index, %s4 : index, %s5 : index, %f : f32) -> memref<?x?x?x?x?xf32> {
  %buf = alloc(%s1, %s2, %s3, %s4, %s5) : memref<?x?x?x?x?xf32>
  linalg.fill(%buf, %f) : memref<?x?x?x?x?xf32>, f32
  return %buf : memref<?x?x?x?x?xf32>
}

func @conv_3d_ncdhw(%arg0: memref<?x?x?x?x?xf32>, %arg1: memref<?x?x?x?x?xf32>, %arg2: memref<?x?x?x?x?xf32>) {
  linalg.conv_3d_ncdhw %arg0, %arg1, %arg2 : (memref<?x?x?x?x?xf32>, memref<?x?x?x?x?xf32>, memref<?x?x?x?x?xf32>)
  return
}

func @main() {
  %c0 = constant 0 : index
  %c1 = constant 1 : index
  %c3 = constant 3 : index
  %c6 = constant 6 : index
  %c8 = constant 8 : index
  %f10 = constant 10.00000e+00 : f32
  %val = constant 2.00000e+00 : f32
  %zero = constant 0.00000e+00 : f32

  %filter3D_ncdhw = call @alloc_5d_filled_f32(%c1, %c1, %c3, %c3, %c3, %val) : (index, index, index, index, index, f32) -> (memref<?x?x?x?x?xf32>)
  %in3D_ncdhw = call @alloc_5d_filled_f32(%c1, %c1, %c8, %c8, %c8, %val) : (index, index, index, index, index, f32) -> (memref<?x?x?x?x?xf32>)
  %out3D_ncdhw = call @alloc_5d_filled_f32(%c1, %c1, %c6, %c6, %c6, %zero) : (index, index, index, index, index, f32) -> (memref<?x?x?x?x?xf32>)

  store %f10, %in3D_ncdhw[%c0, %c0, %c0, %c0, %c3] : memref<?x?x?x?x?xf32>
  call @conv_3d_ncdhw(%in3D_ncdhw, %filter3D_ncdhw, %out3D_ncdhw) : (memref<?x?x?x?x?xf32>, memref<?x?x?x?x?xf32>, memref<?x?x?x?x?xf32>) -> ()
  %out3D_ncdhw_ = memref_cast %out3D_ncdhw : memref<?x?x?x?x?xf32> to memref<*xf32>
  call @print_memref_f32(%out3D_ncdhw_): (memref<*xf32>) -> ()

  dealloc %filter3D_ncdhw : memref<?x?x?x?x?xf32>
  dealloc %in3D_ncdhw : memref<?x?x?x?x?xf32>
  dealloc %out3D_ncdhw : memref<?x?x?x?x?xf32>
  return
}

// CHECK:       Unranked Memref {{.*}}
// CHECK-NEXT:  [
// CHECK-SAME:   [
// CHECK-SAME:    [
// CHECK-SAME:     [
// CHECK-SAME:      [108,      124,      124,      124,      108,      108],
// CHECK-COUNT-5:   [108,      108,      108,      108,      108,      108]
// CHECK-SAME:     ],
// CHECK-NEXT:     [
// CHECK-COUNT-6:   [108,      108,      108,      108,      108,      108]
// CHECK-SAME:     ],
// CHECK-NEXT:     [
// CHECK-COUNT-6:   [108,      108,      108,      108,      108,      108]
// CHECK-SAME:     ],
// CHECK-NEXT:     [
// CHECK-COUNT-6:   [108,      108,      108,      108,      108,      108]
// CHECK-SAME:     ],
// CHECK-NEXT:     [
// CHECK-COUNT-6:   [108,      108,      108,      108,      108,      108]
// CHECK-SAME:     ],
// CHECK-NEXT:     [
// CHECK-COUNT-6:   [108,      108,      108,      108,      108,      108]
// CHECK-SAME:     ]
// CHECK-SAME:    ]
// CHECK-SAME:   ]
// CHECK-SAME:  ]
