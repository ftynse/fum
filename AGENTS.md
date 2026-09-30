# Project Guidelines

## Review and implementation habits

- Review the entire diff for repeated issues, not only the lines explicitly
  commented on.
- Prefer adding tests to an existing relevant test file. Create a new test file
  only when the test is sufficiently different from the existing files.
- Avoid unnecessary `auto` in C++ code. Use explicit types except for iterators,
  lambdas, when the expression right-hand side is a cast or a constructor,
  and for other cases where the full type is excessively long.
- Keep custom assembly syntax strict and intentional. Do not accept alternate
  forms unless they are explicitly part of the requested syntax.
- In FileCheck tests, do not assume or capture generated names or
  prefixes; wildcard the complete label after the sigil.
- All top-level functions, classes, variables, etc. must have a brief
  documentation comment.
- Comments must only describe the current state of the code and only the
  immediate code, avoid debugging stories, failed attempt descriptions and other
  prose unless explicitly asked.

## Validation

- Run the focused test and the full test suite after changes when the build is
  available.
- Use the shared ccache configured by the environment across related projects.
  If sandbox permissions block access, request targeted permission for the
  configured ccache path instead of disabling ccache or switching to a
  project-local cache.
- Run `pre-commit` and other linters only on files in the pending changes or
  changed by the latest commit. Do not run repository-wide linting unless
  explicitly requested, and never include incidental formatting changes to
  unrelated files.
