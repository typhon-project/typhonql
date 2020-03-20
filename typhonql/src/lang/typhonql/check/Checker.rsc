module lang::typhonql::check::Checker

import lang::typhonml::TyphonML;
extend analysis::typepal::TypePal;

extend lang::typhonql::DML;
extend lang::typhonql::Query;

data AType
    = intType()
    | uuidType()
    | stringType()
    | pointType()
    | polygonType()
    | boolType()
    | floatType()
    | blobType()
    | freeTextType(list[str] nlpFeatures)
    | dateType()
    | dateTimeType()
    ;
    
    
data AType
    = entityType(str name)
    | userDefinedType(str name)
    ;



void collect((Expr)`<Int i>`, Collector c) {
    c.fact(i, intType());
}

void collect((Expr)`<Str s>`, Collector c) {
    c.fact(s, stringType());
}

void collect((Expr)`<Real r>`, Collector c) {
    c.fact(r, floatType());
}

void collect((Expr)`<DateTime dt>`, Collector c) {
    c.fact(dt, dateTimeType());
}

void collect((Expr)`<Bool b>`, Collector c) {
    c.fact(b, boolType());
}

void collect((Expr)`<UUID u>`, Collector c) {
    c.fact(u, uuidType());
}


void collect(current:(Expr)`<Expr lhs> * <Expr rhs>`, Collector c) {
    collectInfix(lhs, rhs, "*", current, c);
}

void collect(current:(Expr)`<Expr lhs> / <Expr rhs>`, Collector c) {
    collectInfix(lhs, rhs, "/", current, c);
}

void collect(current:(Expr)`<Expr lhs> + <Expr rhs>`, Collector c) {
    collectInfix(lhs, rhs, "+", current, c);
}

void collect(current:(Expr)`<Expr lhs> - <Expr rhs>`, Collector c) {
    collectInfix(lhs, rhs, "-", current, c);
}

void collect(current:(Expr)`<Expr lhs> == <Expr rhs>`, Collector c) {
    collectInfix(lhs, rhs, "==", current, c);
}

void collect(current:(Expr)`<Expr lhs> != <Expr rhs>`, Collector c) {
    collectInfix(lhs, rhs, "!=", current, c);
}

void collectInfix(Expr lhs, Expr rhs, str op, Expr current, Collector c) {
    collect(lhs, rhs, c);
    c.calculate("<op>", current, [lhs, rhs], AType (Solver s) {
        return calcInfix(op, {s.getType(lhs), s.getType(rhs)}, current);
    });
}


set[str] mathOps = {"+", "*", "/", "-"};
set[AType] numericTypes = {intType(), stringType(), floatType()};
set[AType] comparableTypes = numericTypes + {dateTimeType(), dateType()};

AType calcInfix(str op, {AType singleType}, _) = singleType
    when op in mathOps && singleType in numericTypes;

AType calcInfix(str op, {intType(), floatType()}, _) = floatType()
    when op in mathOps;
   
AType calcInfix("+", {stringType(), _}, _) = stringType();
    
AType calcInfix(str op, {AType singleType}, _) = boolType()
    when op in {"==", "!="};
    
AType calcInfix(str op, {AType singleType}, _) = boolType()
    when op in {"\>=", "\<=", "\>", "\<"} && singleType in comparableTypes;

AType calcInfix("&&", {boolType()}, _) = boolType();
AType calcInfix("||", {boolType()}, _) = boolType();

default AType calcInfix(str op, set[AType] types, Tree current) {
    throw error(current, "%v not supported between %v", op, types);
}

TModel checkQLTree(Tree t, Model mlModel, bool debug = false) {
    return collectAndSolve(t);
}


