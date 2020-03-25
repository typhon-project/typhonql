module lang::typhonql::check::Checker

import IO;
import lang::typhonml::TyphonML;
extend analysis::typepal::TypePal;

extend lang::typhonql::DML;
extend lang::typhonql::Query;

data AType
    = voidType()
    | intType()
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

str prettyAType(voidType()) = "void";
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

bool qlSubType(voidType(), _) = true;

default bool qlSubType(AType a, AType b) = false;


/****************/
/** Expression **/
/****************/

void collect(current:(Expr)`<VId var> . <{Id "."}+ attrs>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`<VId var>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`<PlaceHolder p>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`<VId var>. @id`, Collector c) {
    reportUnsupported(current, c);
}

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

void collect(current:(Expr)`(<Expr arg>)`, Collector c) {
    c.fact(current, arg);
    collect(arg, c);
}

void collect(current:(Expr)`<Obj objValue>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`<Custom customValue>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`<Custom customValue>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`[<{Obj ","}*entries>]`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`[<{UUID ","}+ refs>]`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`null`, Collector c) {
    c.fact(current, voidType());
}

void collect(current:(Expr)`+ <Expr arg>`, Collector c) {
    collect(arg, c);
    c.fact(current, arg);
    c.requireComparable(intType(), arg, error(arg, "Numeric type expected, got %t", arg));
}

void collect(current:(Expr)`- <Expr arg>`, Collector c) {
    collect(arg, c);
    c.fact(current, arg);
    c.requireComparable(intType(), arg, error(arg, "Numeric type expected, got %t", arg));
}

void collect(current:(Expr)`<VId name> (<{Expr ","}* args>)`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`! <Expr arg>`, Collector c) {
    collect(arg, c);
    c.fact(current, boolType());
    c.requireEqual(boolType(), arg, error(arg, "Expected bool type, got %t", arg));
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

void collect(current:(Expr)`<Expr lhs> in <Expr rhs>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`<Expr lhs> like <Expr rhs>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`<Expr lhs> && <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "&&", current, c);
}

void collect(current:(Expr)`<Expr lhs> || <Expr rhs>`, Collector c) {
    collectBoolInfix(lhs, rhs, "||", current, c);
}

// TODO: in + like

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


/***********/
/** Query **/
/***********/

void collect(current:(Query)`from <{Binding ","}+ bindings> select <{Result ","}+ selected> <Where? where> <GroupBy? groupBy> <OrderBy? orderBy>`, Collector c) {
    reportUnsupported(current, c);
}

void reportUnsupported(Tree current, Collector c) {
    c.report(error(current, "`%v` is not supported the typechecker (yet)", current));
}

private TypePalConfig buildConfig(bool debug) 
    = tconfig(
        verbose=debug, logTModel = debug,
        isSubType = qlSubType
    );



TModel checkQLTree(Tree t, Model mlModel, bool debug = false) {
    return collectAndSolve(t, config=buildConfig(debug));
}


