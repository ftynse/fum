# Contrary to what the name claims, this only produces the _op_ interface. The
# type interface is produced manually below.
add_mlir_interface(DepOpInterfaces)
add_mlir_doc(DepOpInterfaces DepOpInterfaces Dialects/ -gen-op-interface-docs)

set(LLVM_TARGET_DEFINITIONS DepTypeInterfaces.td)
mlir_tablegen(DepTypeInterfaces.h.inc -gen-type-interface-decls)
mlir_tablegen(DepTypeInterfaces.cpp.inc -gen-type-interface-defs)
add_mlir_dialect_tablegen_target(MLIRDepTypeInterfacesIncGen)
add_mlir_doc(DepTypeInterfaces DepTypeInterfaces Dialects/ -gen-type-interface-docs)
