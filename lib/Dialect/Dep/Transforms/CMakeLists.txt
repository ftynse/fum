add_mlir_dialect_library(MLIRDepTransforms
  Passes.cpp

  ADDITIONAL_HEADER_DIRS
  ${PROJECT_SOURCE_DIR}/include/

  DEPENDS
  MLIRDepPassesIncGen

  LINK_LIBS PUBLIC
  MLIRDepDialect
  MLIRDepInterfaces
  MLIRPass
  MLIRFuncDialect
  )
