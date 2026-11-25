// RUN: fum-opt %s --split-input-file --verify-diagnostics

// expected-error @below {{expects at least one case}}
func.func private @empty(!adt.sum<>)

// -----

// expected-error @below {{expected a case name}}
func.func private @unnamed(!adt.sum<(i32)>)

// -----

// expected-error @below {{expects distinct case names, got 'a' twice}}
func.func private @duplicate(!adt.sum<a, a(i32)>)

// -----

func.func @make_unknown_case() {
  // expected-error @below {{expects 'c' to be a case of '!adt.sum<a, b>'}}
  %c = adt.make c : !adt.sum<a, b>
  return
}

// -----

func.func @switch_not_exhaustive(%s: !adt.sum<a, b>) {
  // expected-error @below {{expects every case to be listed, or a default case}}
  adt.switch %s : !adt.sum<a, b>, [
    a: ^a
  ]
^a:
  return
}

// -----

func.func @switch_useless_default(%s: !adt.sum<a>) {
  // expected-error @below {{expects the default case to handle at least one case}}
  adt.switch %s : !adt.sum<a>, [
    default: ^a,
    a: ^a
  ]
^a:
  return
}

// -----

func.func @switch_wrong_fields(%s: !adt.sum<a(i32)>) {
  // expected-error @below {{expects the successor of case 'a' to take arguments of types ('i32')}}
  adt.switch %s : !adt.sum<a(i32)>, [
    a: ^a
  ]
^a(%x: i64):
  return
}
