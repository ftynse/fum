//===- DepTypes.cpp - Dep dialect types -----------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "fum/Dialect/Dep/IR/DepTypes.h"

#include "fum/Dialect/Dep/IR/DepDialect.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/TypeSwitch.h"

using namespace mlir;
using namespace mlir::dep;

#define GET_TYPEDEF_CLASSES
#include "fum/Dialect/Dep/IR/DepTypes.cpp.inc"

Type ConstructedTypeType::parse(AsmParser &parser) {
  SMLoc typeLoc = parser.getCurrentLocation();
  SymbolRefAttr constructor;
  SmallVector<Attribute> params;
  auto parseParam = [&]() -> ParseResult {
    return parser.parseAttribute(params.emplace_back());
  };

  if (parser.parseLess() || parser.parseAttribute(constructor) ||
      parser.parseCommaSeparatedList(AsmParser::Delimiter::Paren, parseParam) ||
      parser.parseGreater())
    return Type();

  return getChecked([&] { return parser.emitError(typeLoc); },
                    parser.getContext(), constructor,
                    parser.getBuilder().getArrayAttr(params));
}

void ConstructedTypeType::print(AsmPrinter &printer) const {
  printer << '<';
  printer.printAttribute(getConstructor());
  printer << '(';
  llvm::interleaveComma(getTypeParams(), printer, [&](Attribute param) {
    printer.printAttribute(param);
  });
  printer << ")>";
}

LogicalResult
ConstructedTypeType::verify(function_ref<InFlightDiagnostic()> emitError,
                            SymbolRefAttr, ArrayAttr params) {
  if (!llvm::all_of(params,
                    [](Attribute param) { return isa<StringAttr>(param); }))
    return emitError()
           << "expected constructed type parameters to be string attributes";
  return success();
}

void DepDialect::registerTypes() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "fum/Dialect/Dep/IR/DepTypes.cpp.inc"
      >();
}
