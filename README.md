# fum - fun with mlir

Also functional programming in MLIR. Which may be fun.

## Building

This setup assumes that you have built LLVM and MLIR in `$BUILD_DIR` and installed them to `$PREFIX`. If you do not, download [read this](https://mlir.llvm.org/getting_started/) first. To build and launch the tests, run

```sh
mkdir build
cmake -G Ninja -B build -S . \
  -DMLIR_DIR=$BUILD_DIR/lib/cmake/mlir \
  -DLLVM_EXTERNAL_LIT=$BUILD_DIR/bin/llvm-lit \
  -DMLIR_INCLUDE_TESTS=On
cmake --build build --target check-fum
```

This will run the tests and, as a side effect, produce a binary `fum-opt` that is usable largely similar to `mlir-opt`.

You can also have fum built with pre-installed MLIR as long as it also installs `llvm-lit` (needed for testing). Just repoint `$BUILD_DIR` to the installation root.

## Contributing

Ensure [`pre-commit`](https://pre-commit.com/) is installed and available, turn on the checks with git: `pre-commit install`. The checks must pass for any code to be merged.

This project follows the [MLIR coding standards](https://mlir.llvm.org/getting_started/DeveloperGuide/).

## LLM Usage

LLM usage is permitted to generate code provided it is the reviewed and cleaned up by the author before submitting for review. It is also permitted for internal self-review, brainstorming, ideation, etc. In any cases, the human author is held responsible for their contribution and certifies they have the right to contribute the material under the [applicable license](LICENSE.TXT).

LLM usage is *NOT* permitted in communication channels intended for human consumption, including pull request descriptions, reviews, issues, comments. Please edit the text produced by an LLM for brevity and clarity, avoid unnecessary jargon and complexity.
