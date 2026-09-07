add_mlir_dialect_library(MLIRDepDialect
  DepTypes.cpp
  DepDialect.cpp
  DepOps.cpp

  ADDITIONAL_HEADER_DIRS
  ${PROJECT_SOURCE_DIR}/include/

  DEPENDS
  MLIRDepOpsIncGen
  MLIRDepPassesIncGen

  LINK_LIBS PUBLIC
  MLIRIR
  MLIRInferTypeOpInterface
  MLIRDepInterfaces
  )
