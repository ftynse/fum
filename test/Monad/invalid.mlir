// RUN: fum-opt %s --split-input-file --verify-diagnostics

func.func @return_value_type_mismatch(%value: i64) {
  // expected-error @below {{failed to verify that value types match the value types of the result}}
  %result = "monad.return"(%value) : (i64) -> !monad.maybe<i32>
  return
}

// -----

func.func @return_value_count_mismatch(%value: i32) {
  // expected-error @below {{failed to verify that value types match the value types of the result}}
  %result = "monad.return"(%value) : (i32) -> !monad.maybe<i32, i32>
  return
}

// -----

// expected-note @below {{prior use here}}
func.func @return_value_type_mismatch_custom_syntax(%value: i64) {
  // expected-error @below {{use of value '%value' expects different type than prior uses: 'i32' vs 'i64'}}
  %result = monad.return %value : !monad.maybe<i32>
  return
}

// -----

func.func @return_not_monadic(%value: i32) {
  // expected-error @below {{result #0 must be MonadTypeInterface instance, but got 'i32'}}
  %result = "monad.return"(%value) : (i32) -> i32
  return
}

// -----

func.func @return_unqualified_type(%value: i32) {
  // expected-error @below {{expected non-function type}}
  %result = monad.return %value : <i32>
  return
}

// -----

func.func @maybe_none_not_maybe() {
  // expected-error @below {{result #0 must be Maybe monad type, but got 'i32'}}
  %result = "monad.maybe.none"() : () -> i32
  return
}

// -----

func.func @maybe_none_with_operand(%error: i8) {
  // expected-error @below {{requires zero operands}}
  %result = "monad.maybe.none"(%error) : (i8) -> !monad.maybe<i32>
  return
}

// -----

// expected-error @below {{expected '<'}}
func.func private @maybe_without_parameters(!monad.maybe)

// -----

// expected-error @below {{expected non-function type}}
func.func private @maybe_with_trailing_comma(!monad.maybe<i32,>)

// -----

func.func @do_not_monadic() {
  // expected-error @below {{result #0 must be MonadTypeInterface instance, but got 'i32'}}
  %result = monad.do : i32 {
    %zero = arith.constant 0 : i32
    %wrapped = monad.return %zero : !monad.maybe<i32>
    monad.yield %wrapped : !monad.maybe<i32>
  }
  return
}

// -----

// -----

func.func @bind_outside_do(%input: !monad.maybe<i32>) {
  // expected-error @below {{expects parent op 'monad.do'}}
  monad.bind %input, ^next : !monad.maybe<i32>
^next(%value: i32):
  return
}

// -----

func.func @bind_input_not_monadic(%input: i32) {
  %result = monad.do : !monad.maybe<i32> {
    // expected-error @below {{operand #0 must be MonadTypeInterface instance, but got 'i32'}}
    "monad.bind"(%input) [^next] : (i32) -> ()
  ^next(%value: i32):
    %none = monad.maybe.none : !monad.maybe<i32>
    monad.yield %none : !monad.maybe<i32>
  }
  return
}

// -----

func.func @bind_successor_type_mismatch(%input: !monad.maybe<i32>) {
  %result = monad.do : !monad.maybe<i32> {
    // expected-error @below {{expects the successor to take arguments of types ('i32')}}
    monad.bind %input, ^next : !monad.maybe<i32>
  ^next(%value: f32):
    %none = monad.maybe.none : !monad.maybe<i32>
    monad.yield %none : !monad.maybe<i32>
  }
  return
}

// -----

func.func @bind_successor_count_mismatch(%input: !monad.maybe<i32, i32>) {
  %result = monad.do : !monad.maybe<i32> {
    // expected-error @below {{branch has 2 operands for successor #0, but target block has 1}}
    monad.bind %input, ^next : !monad.maybe<i32, i32>
  ^next(%value: i32):
    %none = monad.maybe.none : !monad.maybe<i32>
    monad.yield %none : !monad.maybe<i32>
  }
  return
}

// -----

func.func @bind_without_successor(%input: !monad.maybe<i32>) {
  %result = monad.do : !monad.maybe<i32> {
    // expected-error @below {{expected ','}}
    monad.bind %input : !monad.maybe<i32>
  }
  return
}

// -----

func.func @yield_outside_do(%input: !monad.maybe<i32>) -> !monad.maybe<i32> {
  // expected-error @below {{expects parent op 'monad.do'}}
  monad.yield %input : !monad.maybe<i32>
}

// -----

func.func @yield_type_mismatch(%input: !monad.maybe<i32>) {
  %result = monad.do : !monad.maybe<f32> {
    // expected-error @below {{expects the yielded value to be of the result type of the enclosing monad.do, '!monad.maybe<f32>', got '!monad.maybe<i32>'}}
    monad.yield %input : !monad.maybe<i32>
  }
  return
}

// -----

func.func @do_block_without_terminator(%input: !monad.maybe<i32>) {
  %result = monad.do : !monad.maybe<i32> {
    // expected-error @below {{block with no terminator}}
    %none = monad.maybe.none : !monad.maybe<i32>
  }
  return
}

// -----

// Reject a non-entry block without a predecessor.
func.func @do_block_without_predecessor(%input: !monad.maybe<i32>) {
  // expected-error @below {{expects every block except the first to have exactly one predecessor}}
  %result = monad.do : !monad.maybe<i32> {
    monad.yield %input : !monad.maybe<i32>
  ^unreachable:
    monad.yield %input : !monad.maybe<i32>
  }
  return
}

// -----

// Reject a block reached by both the entry block and a backedge.
func.func @do_block_with_multiple_predecessors(%input: !monad.maybe<>) {
  // expected-error @below {{expects every block except the first to have exactly one predecessor}}
  %result = monad.do : !monad.maybe<> {
    monad.bind %input, ^loop : !monad.maybe<>
  ^loop:
    monad.bind %input, ^loop : !monad.maybe<>
  }
  return
}

// -----

// Reject a foreign terminator in the entry block.
func.func @do_entry_block_with_foreign_terminator() {
  // expected-error @below {{expects every block terminator to belong to the monad dialect}}
  %result = monad.do : !monad.maybe<> {
    dep.yield
  }
  return
}

// -----

// Reject a foreign terminator in a continuation block.
func.func @do_continuation_with_foreign_terminator(%input: !monad.maybe<>) {
  // expected-error @below {{expects every block terminator to belong to the monad dialect}}
  %result = monad.do : !monad.maybe<> {
    monad.bind %input, ^next : !monad.maybe<>
  ^next:
    dep.yield
  }
  return
}

// -----

// expected-error @below {{expects a non-empty error name}}
func.func private @error_with_empty_name() attributes {error = #monad.error<"">}

// -----

// expected-error @below {{expected distinct errors, got #monad.error<"a"> twice}}
func.func private @either_with_duplicate_error(!monad.either<[i32] throws {#monad.error<"a">, #monad.error<"a">}>)

// -----

// expected-error @below {{expected an error, got 1 : i32}}
func.func private @either_with_non_error(!monad.either<[i32] throws {1 : i32}>)

// -----

// expected-error @below {{expected 'throws'}}
func.func private @either_without_errors(!monad.either<[i32]>)

// -----

func.func @bind_other_errors(%input: !monad.either<[i32] throws {#monad.error<"a">}>) {
  %result = monad.do : !monad.either<[i32] throws {#monad.error<"b">}> {
    // expected-error @below {{expects the input to be of the monad of the enclosing monad.do}}
    monad.bind %input, ^next : !monad.either<[i32] throws {#monad.error<"a">}>
  ^next(%value: i32):
    %wrapped = monad.return %value : !monad.either<[i32] throws {#monad.error<"b">}>
    monad.yield %wrapped : !monad.either<[i32] throws {#monad.error<"b">}>
  }
  return
}

// -----

func.func @bind_maybe_in_either(%input: !monad.maybe<i32>) {
  %result = monad.do : !monad.either<[i32] throws {#monad.error<"a">}> {
    // expected-error @below {{expects the input to be of the monad of the enclosing monad.do}}
    monad.bind %input, ^next : !monad.maybe<i32>
  ^next(%value: i32):
    %wrapped = monad.return %value : !monad.either<[i32] throws {#monad.error<"a">}>
    monad.yield %wrapped : !monad.either<[i32] throws {#monad.error<"a">}>
  }
  return
}
