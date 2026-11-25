add_mlir_dialect_library(MLIRADTDialect
  ADTDialect.cpp
  ADTOps.cpp
  ADTTypes.cpp

  ADDITIONAL_HEADER_DIRS
  ${PROJECT_SOURCE_DIR}/include/

  DEPENDS
  MLIRADTOpsIncGen

  LINK_LIBS PUBLIC
  MLIRControlFlowInterfaces
  MLIRIR
  MLIRSideEffectInterfaces
  )
