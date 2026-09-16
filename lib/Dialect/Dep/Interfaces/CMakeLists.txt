add_mlir_dialect_library(MLIRDepInterfaces
  DepOpInterfaces.cpp
  DepTypeInterfaces.cpp

  ADDITIONAL_HEADER_DIRS
  ${PROJECT_SOURCE_DIR}/include/

  DEPENDS
  MLIRDepOpInterfacesIncGen
  MLIRDepTypeInterfacesIncGen

  LINK_LIBS PUBLIC
  MLIRIR
)
