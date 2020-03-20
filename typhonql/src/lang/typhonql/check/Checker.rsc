module lang::typhonql::check::Checker

import lang::typhonml::TyphonML;
extend analysis::typepal::TypePal;

extend lang::typhonql::DML;
extend lang::typhonql::Query;

data AType
    = intType()
    | bigIntType()
    | uuidType()
    | stringType()
    | textType()
    | pointType()
    | polygonType()
    | boolType()
    | floatType()
    | blobType()
    | freeTextType(list[str] nlpFeatures)
    | dateType()
    | dateTimeType()
    ;

str prettyAType(intType()) = "int";
str prettyAType(bigIntType()) = "bigint";
str prettyAType(uuidType()) = "uuid";
str prettyAType(stringType()) = "string";
str prettyAType(textType()) = "text";
str prettyAType(pointType()) = "point";
str prettyAType(polygonType()) = "polygon";
str prettyAType(boolType()) = "bool";
str prettyAType(floatType()) = "float";
str prettyAType(blobType()) = "blob";
str prettyAType(freeTextType(nlpFeatures)) = "freetext[<intercalate(",", nlpFeatures)>]";
str prettyAType(dateType()) = "date";
str prettyAType(dateTimeType()) = "datetime";
    
    
data AType
    = entityType(str name)
    | userDefinedType(str name)
    ;

str prettyAType(entityType(str name)) = name;
str prettyAType(userDefinedType(str name)) = name;


bool qlSubType(intType(), bigIntType()) = true;
bool qlSubType(intType(), floatType()) = true;
bool qlSubType(bigIntType(), floatType()) = true;

bool qlSubType(stringType(), textType()) = true;
bool qlSubType(textType(), stringType()) = true;

bool qlSubType(uuidType(), entityType(_)) = true;


default bool qlSubType(AType a, AType b) = false;

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
    collectBoolInfix(lhs, rhs, "==", current, c);
}

void collect(current:(Expr)`<Expr lhs> != <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "!=", current, c);
}

void collect(current:(Expr)`<Expr lhs> \>= <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "\>=", current, c);
}

void collect(current:(Expr)`<Expr lhs> \<= <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "\<=", current, c);
}

void collect(current:(Expr)`<Expr lhs> \> <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "\>", current, c);
}

void collect(current:(Expr)`<Expr lhs> \< <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "\<", current, c);
}

void collect(current:(Expr)`<Expr lhs> && <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "&&", current, c);
}

void collect(current:(Expr)`<Expr lhs> || <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "||", current, c);
}

// TODO: in + like
// TODO: prefix expr

void collectInfix(Expr lhs, Expr rhs, str op, Expr current, Collector c) {
    collect(lhs, rhs, c);
    c.calculate("<op>", current, [lhs, rhs], AType (Solver s) {
        try {
            return calcInfix(op, {s.getType(lhs), s.getType(rhs)}, s);
        } catch "unsupported": {
            s.report(error(current, "%v not supported between %t and %t", op, lhs, rhs));
            return intType(); // never reached since error throws an exception
        }
    });
}

void collectBoolInfix(Expr lhs, Expr rhs, str op, Expr current, Collector c) {
    collect(lhs, rhs, c);
    c.fact(current, boolType());
    if (op in {"&&", "||"}) {
        c.requireEqual(boolType(), lhs, error(lhs, "%v expects bool types (got %t)", lhs));
        c.requireEqual(boolType(), rhs, error(rhs, "%v expects bool types (got %t)", rhs));
    }
    else {
        c.requireComparable(lhs, rhs, error(current, "Cannot compare %t and %t", lhs, rhs));
        if (op notin {"==", "!="}) {
            // we only have to check one side to know if they are incorrect
            c.require(op, current, [lhs], void (Solver s) {
                s.requireTrue(s.getType(lhs) in orderableTypes, error(current, "Cannot compare things of type %t", lhs));
            });
        }
    }
}


set[str] mathOps = {"+", "*", "/", "-"};
set[AType] numericTypes = {intType(), stringType(), floatType()};
set[AType] orderableTypes = numericTypes + {dateTimeType(), dateType()};

AType calcInfix(str op, {AType singleType}, _) = singleType
    when op in mathOps && singleType in numericTypes;

AType calcInfix(str op, {intType(), floatType()}, _) = floatType()
    when op in mathOps;
   
AType calcInfix("+", {stringType(), _}, _) = stringType(); // allow concat on many things
    
default AType calcInfix(_, _, _) {
    throw "unsupported";
}

private TypePalConfig buildConfig(bool debug) 
    = tconfig(
        verbose=debug, logTModel = debug,
        isSubType = qlSubType
    );


TModel checkQLTree(Tree t, Model mlModel, bool debug = false) {
    return collectAndSolve(t, config=buildConfig(debug));
}


