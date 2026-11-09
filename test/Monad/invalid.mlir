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
