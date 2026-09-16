# TODO: Make it possible to use XDialect instead of XOpsDialect in
# add_mlir_dialect.
set(LLVM_TARGET_DEFINITIONS DepDialect.td)
mlir_tablegen(DepDialect.h.inc -gen-dialect-decls -dialect=dep)
mlir_tablegen(DepDialect.cpp.inc -gen-dialect-defs -dialect=dep)
add_mlir_dialect_tablegen_target(MLIRDepDialectIncGen)
add_mlir_doc(DepDialect DepDialect Dep/ -gen-dialect-doc)

set(LLVM_TARGET_DEFINITIONS DepTypes.td)
mlir_tablegen(DepTypes.h.inc -gen-typedef-decls)
mlir_tablegen(DepTypes.cpp.inc -gen-typedef-defs)
add_mlir_dialect_tablegen_target(MLIRDepTypesIncGen)
add_mlir_doc(DepTypes DepTypes Dialects/ -gen-typedef-doc -dialect=transform)

add_mlir_dialect(DepOps dep)
add_mlir_doc(DepOps DepOps Dep/ -gen-op-doc)
