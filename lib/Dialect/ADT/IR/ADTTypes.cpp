//===- ADTTypes.cpp - ADT dialect types -------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/ADT/IR/ADTTypes.h"
#include "fum/Dialect/ADT/IR/ADTDialect.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "llvm/ADT/TypeSwitch.h"

using namespace mlir;
using namespace mlir::adt;

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/ADT/IR/ADTOpsTypes.cpp.inc"

void ADTDialect::registerTypes() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "fum/Dialect/ADT/IR/ADTOpsTypes.cpp.inc"
      >();
}

/// Parses `<case, ...>`, where a case is a name followed by its field types
/// in parentheses, if it has any.
Type SumType::parse(AsmParser &parser) {
  SMLoc loc = parser.getCurrentLocation();
  Builder &builder = parser.getBuilder();
  SmallVector<NamedAttribute> cases;
  auto parseCase = [&]() -> ParseResult {
    StringRef name;
    SmallVector<Type> fields;
    if (parser.parseOptionalKeyword(&name))
      return parser.emitError(parser.getCurrentLocation(),
                              "expected a case name");
    if (succeeded(parser.parseOptionalLParen()) &&
        (parser.parseTypeList(fields) || parser.parseRParen()))
      return failure();
    cases.push_back(
        builder.getNamedAttr(name, builder.getTypeArrayAttr(fields)));
    return success();
  };
  if (parser.parseCommaSeparatedList(AsmParser::Delimiter::LessGreater,
                                     parseCase))
    return {};
  if (std::optional<NamedAttribute> duplicate =
          DictionaryAttr::findDuplicate(cases, /*isSorted=*/false)) {
    parser.emitError(loc) << "expects distinct case names, got '"
                          << duplicate->getName().getValue() << "' twice";
    return {};
  }
  return parser.getChecked<SumType>(
      loc, parser.getContext(),
      DictionaryAttr::getWithSorted(parser.getContext(), cases));
}

void SumType::print(AsmPrinter &printer) const {
  printer << '<';
  llvm::interleaveComma(getCases(), printer, [&](NamedAttribute sumCase) {
    printer << sumCase.getName().getValue();
    ArrayAttr fields = cast<ArrayAttr>(sumCase.getValue());
    if (fields.empty())
      return;
    printer << '(';
    llvm::interleaveComma(fields.getAsValueRange<TypeAttr>(), printer);
    printer << ')';
  });
  printer << '>';
}

/// Verifies that there is at least one case and that every case maps to an
/// array of types.
LogicalResult SumType::verify(function_ref<InFlightDiagnostic()> emitError,
                              DictionaryAttr cases) {
  if (cases.empty())
    return emitError() << "expects at least one case";
  for (NamedAttribute sumCase : cases) {
    ArrayAttr fields = dyn_cast<ArrayAttr>(sumCase.getValue());
    if (!fields || !llvm::all_of(fields, llvm::IsaPred<TypeAttr>))
      return emitError() << "expects the fields of case '"
                         << sumCase.getName().getValue()
                         << "' to be an array of types";
  }
  return success();
}

std::optional<SmallVector<Type>> SumType::getCaseFields(StringRef name) const {
  ArrayAttr fields = getCases().getAs<ArrayAttr>(name);
  if (!fields)
    return std::nullopt;
  return llvm::to_vector(fields.getAsValueRange<TypeAttr>());
}
