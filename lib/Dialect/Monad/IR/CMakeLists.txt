add_mlir_dialect_library(MLIRMonadDialect
  MonadAttrs.cpp
  MonadDialect.cpp
  MonadOps.cpp
  MonadTypes.cpp

  ADDITIONAL_HEADER_DIRS
  ${PROJECT_SOURCE_DIR}/include/

  DEPENDS
  MLIRMonadAttrsIncGen
  MLIRMonadOpsIncGen
  MLIRMonadTypeInterfacesIncGen

  LINK_LIBS PUBLIC
  MLIRControlFlowInterfaces
  MLIRIR
  MLIRMonadInterfaces
  MLIRSideEffectInterfaces
  )
