add_mlir_dialect_library(MLIRMonadInterfaces
  MonadTypeInterfaces.cpp

  ADDITIONAL_HEADER_DIRS
  ${PROJECT_SOURCE_DIR}/include/

  DEPENDS
  MLIRMonadTypeInterfacesIncGen

  LINK_LIBS PUBLIC
  MLIRIR
  )
