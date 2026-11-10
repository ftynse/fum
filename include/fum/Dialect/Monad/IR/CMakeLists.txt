add_mlir_dialect(MonadOps monad)

set(LLVM_TARGET_DEFINITIONS MonadAttrs.td)
mlir_tablegen(MonadAttrs.h.inc -gen-attrdef-decls -attrdefs-dialect=monad)
mlir_tablegen(MonadAttrs.cpp.inc -gen-attrdef-defs -attrdefs-dialect=monad)
add_mlir_dialect_tablegen_target(MLIRMonadAttrsIncGen)
add_mlir_doc(MonadOps MonadDialect Monad/ -gen-dialect-doc -dialect=monad)
