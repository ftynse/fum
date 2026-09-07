llvm_canonicalize_cmake_booleans(
        MLIR_ENABLE_BINDINGS_PYTHON
)

configure_lit_site_cfg(
        ${CMAKE_CURRENT_SOURCE_DIR}/lit.site.cfg.py.in
        ${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg.py
        MAIN_CONFIG
        ${CMAKE_CURRENT_SOURCE_DIR}/lit.cfg.py
)

set(DEP_TEST_DEPENDS
        FileCheck count not
        fum-opt
        )

add_lit_testsuite(check-fum "Running the fum tests"
        ${CMAKE_CURRENT_BINARY_DIR}
        DEPENDS ${DEP_TEST_DEPENDS}
        )
set_target_properties(check-fum PROPERTIES FOLDER "Tests")

add_lit_testsuites(DEP ${CMAKE_CURRENT_SOURCE_DIR} DEPENDS ${DEP_TEST_DEPENDS})
