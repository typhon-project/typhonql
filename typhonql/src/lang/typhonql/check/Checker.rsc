/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

module lang::typhonql::check::Checker

import ParseTree;
import String;
import lang::typhonml::TyphonML;
import lang::typhonml::Util;
extend analysis::typepal::TypePal;

import lang::typhonql::TDBC;

/***********
 *  Types  *
 ***********/

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
str prettyAType(freeTextType(nlps)) = "freetext[<intercalate(",", [n | n <- nlps])>]";
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

bool qlSubType(freeTextType(_), stringType()) = true;
bool qlSubType(stringType(), freeTextType(_)) = true;

bool qlSubType(userDefinedType(name), stringType()) = true
	when isNlpCustomDataType(name);
	
bool qlSubType(stringType(), userDefinedType(name)) = true
	when isNlpCustomDataType(name);

bool qlSubType(uuidType(), entityType(_)) = true;

bool qlSubType(voidType(), _) = true;

default bool qlSubType(AType a, AType b) = false;

alias CheckerMLSchema = tuple[map[AType entity, map[str field, tuple[AType typ, Cardinality card] tp] fields] fields, rel[AType from, AType to, AType via] graphEdges];
data TypePalConfig(CheckerMLSchema mlSchema = <(), {}>);

/***********
 *  Roles  *
 ***********/
 
 data IdRole
    = tableRole()
    | fieldRole()
    ;
 

/****************/
/** Expression **/
/****************/

void collect(current:(Expr)`<VId var> . <{Id "."}+ attrs>`, Collector c) {
    c.use(var, {tableRole()});
    Tree parent = var;
    for (a <- attrs) {
        c.useViaType(parent, a, {fieldRole()});
        parent = a;
    }
    c.fact(current, parent);
}

void collect(current:(Expr)`<VId var>`, Collector c) {
    collect(var, c);
}

void collect(VId current, Collector c) {
    c.use(current, {tableRole()});
}

void collect(current:(Expr)`<PlaceHolder p>`, Collector c) {
    c.fact(p, voidType());
}

void collect(current:(Expr)`<VId var>. @id`, Collector c) {
    c.fact(current, uuidType());
    c.use(var, {tableRole()});
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
    if (dt is date) {
        c.fact(dt, dateType());
    }
    else {
        c.fact(dt, dateTimeType());
    }
}

void collect((Expr)`<Point pt >`, Collector c) {
    c.fact(pt, pointType());
}

void collect((Expr)`<Polygon pg>`, Collector c) {
    c.fact(pg, polygonType());
}


void collect((Expr)`<Bool b>`, Collector c) {
    c.fact(b, boolType());
}

void collect((Expr)`<UUID u>`, Collector c) {
    c.fact(u, uuidType());
}

void collect((Expr)`<BlobPointer p>`, Collector c) {
    c.fact(p, blobType());
}

void collect(current:(Expr)`(<Expr arg>)`, Collector c) {
    c.fact(current, arg);
    collect(arg, c);
}

void collect(current:(Expr)`<Obj objValue>`, Collector c) {
    collect(objValue, c);
}

void collect(current:(Obj)`<Label? label> <EId entity> { <{KeyVal ","}* keyVals> }`, Collector c) {
    collectEntityType(entity, c);
    collectKeyVal(keyVals, entity, c);
    if (inInsert(c)) {
        requireAttributesSet(entity, entity, keyVals, c);
    }
}

void collectKeyVal({KeyVal ","}* keyVals, EId entity, Collector c) {
    for (kv <- keyVals) {
        collectKeyVal(kv, entity, c);
    }
}


void collectKeyVal(current:(KeyVal)`@id : <Expr val>`, EId entity, Collector c) {
    collect(val, c);
    c.requireEqual(uuidType(), val, error(current, "Expected uuid but got %t", val));
}

void collectKeyVal(current:(KeyVal)`<Id key> : <Expr val>`, EId entity, Collector c) {
    collect(val, c);
    c.useViaType(entity, key, {fieldRole()});
    c.require("valid assignment", current, [key, val], void (Solver s) {
        if (atypeList([uuidType()]) := s.getType(val)) {
            requireValidCardinality(current, key, entity, s);
        }
        else {
            s.requireTrue(s.equal(key, val) || s.subtype(val, key), error(current, "Expected %t but got %t", key, val));
        }
    });
}

void collectKeyVal(current:(KeyVal)`<Id key> +: <Expr val>`, EId entity, Collector c) {
    if (inInsert(c)) {
        c.report(error(kv, "Update collection not supported in insert"));
    }
    collectKVUpdate(current, key, val, entity, c);
}

void collectKeyVal(current:(KeyVal)`<Id key> -: <Expr val>`, EId entity, Collector c) {
    if (inInsert(c)) {
        c.report(error(kv, "Update collection not supported in insert"));
    }
    collectKVUpdate(current, key, val, entity, c);
}

void collectKVUpdate(KeyVal current, Id key, Expr val, EId entity, Collector c) {
    collect(val, c);
    c.useViaType(entity, key, {fieldRole()});
    c.requireEqual(atypeList([uuidType()]), val, error(val, "Currently only lists of uuids are supported in the update syntax"));
    c.require("valid update", current, [key, val], void (Solver s) {
        requireValidCardinality(current, key, entity, s);
    });
}

void requireValidCardinality(KeyVal current, Id key, EId entity, Solver s) {
    keyType = s.getType(key);
    s.requireTrue(entityType(_) := keyType, error(key, "Expected entity type, got %t", key));
    cardinality = getCardinality(entity, key, s);
    s.requireTrue(cardinality in {zero_many(), one_many()}, error(current, "update not supported on cardinality one or zero-to-one"));
}


void collect(current:(Expr)`<EId typ> ( <{KeyVal ","}* params>)`, Collector c) {
    c.fact(current, typ);
    tp = userDefinedType("<typ>");
    if (tp in c.getConfig().mlSchema.fields) {
        c.fact(typ, tp);
    }
    else {
        c.calculate("invalid user type", typ, [], AType (Solver s) {
            s.report(error(typ, "Not a valid user defined type"));
            return voidType();
        });
    }
    
    collectKeyVal(params, typ, c);
    if (inInsert(c)) {
        requireAttributesSet(typ, typ, params, c);
    }
}

//void collect(current:(Expr)`[<{Obj ","}*entries>]`, Collector c) {
//    if (e <- entries) {
//        collect(entries, c);
//        c.calculate("list type", current, [et | et <- entries], AType (Solver s) {
//            for (et <- entries) {
//                s.requireEqual(e, et, error(et, "Expected same type in the list, found %t and %t", e, et));
//            }
//            return atypeList([s.getType(e)]);
//        });
//    }
//    c.fact(current, atypeList([voidType()]));
//}

// TODO how to type this?
void collect(current:(Expr)`[<{PlaceHolderOrUUID ","}* refs>]`, Collector c) {
    c.fact(current, atypeList([uuidType()]));
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
    collect(args, c);
    collectBuildinFunction(current, name, [e | e <- args], c);
}


void requirePointOrPolygon(Collector c, Tree current, Tree t) {
    c.require("Point or polygon", current, [t], void (Solver s) {
        requirePointOrPolygon(s, t);
    });
}

void requirePointOrPolygon(Solver s, Tree t) {
    s.requireTrue(s.getType(t) in {polygonType(), pointType()}, error(t, "Expected polygon or point, got %t", t));
}

void collectBuildinFunction(Tree current, (VId)`distance`, list[Expr] args, Collector c) {
    c.fact(current, floatType());
    if ([from, to] := args) {
        c.require("check valid argument types", current, [from, to], void (Solver s) {
            requirePointOrPolygon(s, from);
            requirePointOrPolygon(s, to);
        });
    }
    else {
        c.report(error(current, "Invalid number of arguments for distance function, required: 2, gotten: %v", size(args)));
    }
}

void collectBuildinFunction(Tree current, VId f, list[Expr] args, Collector c) {
  if ("<f>" in {"sum", "count", "max", "min", "avg"}) {
    ; // todo
  }
  else {
    c.report(error(current, "Unknown built-in function"));
  }
}


default void collectBuildinFunction(Tree current, _, _, Collector c) {
    c.report(error(current, "Unknown built-in function"));
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
    c.fact(current, boolType());
    c.require("Valid in expression", current, [lhs, rhs], void (Solver s) {
        switch (s.getType(rhs)) {
            case polygonType(): 
                requirePointOrPolygon(s, lhs);
            case AType tp:
                s.report(error(rhs, "Unsupported in expression for %t", tp));
        }
    });
    collect(lhs, rhs, c);
}

void collect(current:(Expr)`<Expr lhs> like <Expr rhs>`, Collector c) {
    reportUnsupported(current, c);
}

void collect(current:(Expr)`<VId lhs> -[ <VId edge> <ReachingBound? bound> ]-\> <VId rhs>`, Collector c) {
    c.fact(current, boolType());
    requireEntityType(lhs, c);
    requireEntityType(rhs, c);
    requireEntityType(edge, c);
    c.require("valid entities involved in graph expression", current, [lhs, edge, rhs], void (Solver s) {
        from = s.getType(lhs);
        to = s.getType(rhs);
        via = s.getType(edge);
        s.requireTrue(<from, to, via> in s.getConfig().mlSchema.graphEdges, error(current, "%t not defined as an edge between %t and %t", via, from, to));
    });
    collect(lhs, edge, rhs, c);
}

void requireEntityType(Tree t, Collector c) {
    c.require("Should be an entity", t, [t], void (Solver s) {
        s.requireTrue(entityType(_) := s.getType(t), error(t, "Expected entity type, but got: %t", t));
    });
}


void collect(current:(Expr)`<Expr lhs> & <Expr rhs>`, Collector c) {
    c.fact(current, boolType());
    requirePointOrPolygon(c, current, lhs);
    requirePointOrPolygon(c, current, rhs);
    collect(lhs, rhs, c);
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

void collectEntityType(EId entityName, Collector c) {
    tp = entityType("<entityName>");
    if (tp in c.getConfig().mlSchema.fields) {
        c.fact(entityName, tp);
    }
    else {
        c.calculate("error", entityName, [], AType (Solver s) {
            s.report(error(entityName, "Missing %v in the typepal configuration", "<entityName>"));
            return voidType();
        });
    }
}


/***********/
/** Query **/
/***********/

void collect(current:(Query)`from <{Binding ","}+ bindings> select <{Result ","}+ selected> <Where? where> <Agg* aggs>`, Collector c) {
    c.enterScope(current);
    collect(bindings, selected, c);
    if (w <- where) {
        collect(w, c);
    }
    for (Agg a <- aggs) {
      collect(a, c);
    }
    c.leaveScope(current);
}

void collect((Result)`<Expr e>`, Collector c) {
    collect(e, c);
}



void collect((Result)`<Expr e> as <VId x>`, Collector c) {
    collect(e, c);
	// TODO    
}

void collect(current:(Binding)`<EId entity> <VId name>`, Collector c) {
    collectEntityType(entity, c);
    c.define("<name>", tableRole(), name, defType(entity));
}


void collect((Where)`where <{Expr ","}+ clauses>`, Collector c) {
    collect(clauses, c);
    for (cl <- clauses) {
        c.requireEqual(boolType(), cl, error(cl, "Where expects a boolean expression"));
    }
}

void collect((Agg)`group <{Expr ","}+ vars>`, Collector c) {
    collect(vars, c);
}

void collect((Agg)`having <{Expr ","}+ clauses>`, Collector c) {
    // TODO: enable this if aliases work.
    //collect(clauses, c);
    //for (cl <- clauses) {
    //    c.requireEqual(boolType(), cl, error(cl, "Having expects a boolean expression"));
    //}
}

void collect((Agg)`order <{Expr ","}+ vars> <Dir _>`, Collector c) {
    // TODO: needs to deal with as-variables
    //collect(vars, c);
}

void collect((Agg)`limit <Expr e>`, Collector c) {
    collect(e, c);
}

/*******
 * DML *
 *******/
 
bool inInsert(Collector c) = true := c.top("insert");
 
void collect(current:(Statement)`insert <{Obj ","}* objs>`, Collector c) {
    c.enterScope(current);
    c.push("insert", true);
    collect(objs, c);
    c.pop("insert");
    c.leaveScope(current);
}

void requireAttributesSet(Tree current, Tree typ, {KeyVal ","}* args, Collector c) {
    keysSet = { key | (KeyVal)`<Id key> : <Expr _>` <- args };
    sch = c.getConfig().mlSchema.fields;
    c.require("Attributes set", current, [typ, *keysSet], void (Solver s) {
        attrs = sch[s.getType(typ)]?();
        required = { k | k <- attrs, <entityType(_), _> !:= attrs[k] };
        missing = required - { "<k>" | k <- keysSet};
        s.requireTrue(missing == {}, error(current, "%t is missing the following attributes: %v", typ, missing));
    });
}


void collect(current:(Statement)`delete <Binding b> <Where? where>`, Collector c) {
    c.enterScope(current);
    collect(b, c);
    if (w <- where) {
        collect(w, c);
    }
    c.leaveScope(current);
}

void collect(current:(Statement)`update <Binding b> <Where? where> set { <{KeyVal ","}* keyVals>}`, Collector c) {
    c.enterScope(current);
    c.push("insert", false);
    collect(b, c);
    if (w <- where) {
        collect(w, c);
    }
    collectKeyVal(keyVals, b.entity, c);
    c.pop("insert");
    c.leaveScope(current);
}


/**********
 * Script *
 **********/
 
void collect(current:(Script)`<Scratch scratch>`, Collector c) {
    collect(scratch, c);
 }

void collect(current:(Scratch)`<Request* requests>`, Collector c) {
    collect(requests, c);
}

void collect(current:(Request)`<Query qry>`, Collector c) {
    collect(qry, c);
}

void collect(current:(Request)`<Statement stm>`, Collector c) {
    collect(stm, c);
}

/*******
 * DDL *
 *******/
 
void collect(current: (Statement)`create <EId _> at <Id _>`, Collector c) {
    reportUnsupported(current, c);
}
void collect(current: (Statement)`create <EId _> . <Id _> : <Type _>`, Collector c) {
    reportUnsupported(current, c);
} 
void collect(current: (Statement)`create <EId _> . <Id _> <Inverse? _> <Arrow _> <EId _> [ <CardinalityEnd _> .. <CardinalityEnd _> ]`, Collector c) {
    reportUnsupported(current, c);
}
void collect(current: (Statement)`drop <EId _>`, Collector c) {
    reportUnsupported(current, c);
}
void collect(current: (Statement)`drop attribute <EId _> . <Id _>`, Collector c) {
    reportUnsupported(current, c);
}
void collect(current: (Statement)`drop relation <EId _> . <Id _>`, Collector c) {
    reportUnsupported(current, c);
}
void collect(current: (Statement)`rename attribute <EId _> . <Id _> to <Id _>`, Collector c) {  
    reportUnsupported(current, c);
}
void collect(current: (Statement)`rename relation <EId _> . <Id _> to <Id _>`, Collector c) {  
    reportUnsupported(current, c);
}

void reportUnsupported(Tree current, Collector c) {
    c.calculate("unsupported", current, [], AType (Solver s) {
        s.report(error(current, "`%v` is not supported the typechecker (yet)", current));
        return voidType();
    });
}

Cardinality getCardinality(EId context, Id fname, Solver s) {
    mlSchema = s.getConfig().mlSchema.fields;
    utype = s.getType(context);
    if (utype in mlSchema) {
        if ("<fname>" in mlSchema[utype]) {
            return mlSchema[utype]["<fname>"].card;
        }
    }
    s.report(error(fname, "<fname> not defined for %t", utype));
    return \one();
}


private TypePalConfig buildConfig(bool debug, CheckerMLSchema mlSchema) 
    = tconfig(
        verbose=debug, logTModel = debug,
        isSubType = qlSubType,
        mlSchema = mlSchema,
        getTypeNamesAndRole = tuple[list[str] typeNames, set[IdRole] idRoles] (AType tp) {
            return <[], {}>;
        },
        getTypeInNamelessType = 
            AType(AType utype, Tree fname, loc scope, Solver s) {
                if (utype in mlSchema.fields) {
                    if ("<fname>" in mlSchema.fields[utype]) {
                        return mlSchema.fields[utype]["<fname>"].typ;
                    }
                }
                s.report(error(fname, "<fname> not defined for %t", utype));
                return voidType();
            }
    );

AType calcMLType("int") = intType();
AType calcMLType("bigint") = intType();
AType calcMLType(/^string[\[\(]/) = stringType();
AType calcMLType("text") = stringType();
AType calcMLType("point") = pointType();
AType calcMLType("polygon") = polygonType();
AType calcMLType("bool") = boolType();
AType calcMLType("float") = floatType();
AType calcMLType("blob") = blobType();
AType calcMLType(/^freetext\[<features:.*>\]$/) = freeTextType([trim(f) | f <- split(",", features)]);
AType calcMLType("date") = dateType();
AType calcMLType("datetime") = dateTimeType();

default AType calcMLType(str tp) {
    throw "Forgot to add support for type <tp>";
}




CheckerMLSchema convertModel(Schema mlSchema) {
    fields = ( entityType(tpn) : 
        (
          (fn : <(ftp in mlSchema.customs<from>) ? userDefinedType(ftp) : calcMLType(ftp), \one()> | <fn, ftp> <- mlSchema.attrs[tpn])
        //+ (fn : <entityType(nlpEntity(tpn)), \one()> | <fn, ftp> <- mlSchema.attrs[tpn], isFreeTextType(ftp))
        + (fn: <userDefinedType(nlpCustomDataType(tpn, fn)), \one()>
    	|  <fn, ftp> <- mlSchema.attrs[tpn], isFreeTextType(ftp))
        + (fr : <entityType(to), fc> | <fc, fr, _, _, to, _> <- mlSchema.rels[tpn])
        + (tr : <entityType(from), tc> | <from, _, _, tr, tc, tpn, _> <- mlSchema.rels)) // inverse roles
    | tpn <- entities(mlSchema)
    ) + (userDefinedType(tpn) : 
        (fn : <(ftp in mlSchema.customs<from>) ? userDefinedType(ftp) : calcMLType(ftp), \one()> | <fn, ftp> <- mlSchema.customs[tpn])   
    | tpn <- mlSchema.customs<from>
    ) + (userDefinedType(tpn) :
    	(fn : <calcMLType(ftp), \one()> |  <actualName, fn, ftp> <- customForNlpAnalysis[tpn])
    | tpn <-  customForNlpAnalysis
    ) + (userDefinedType(nlpCustomDataType(tpn, fn)) :
       (an: <userDefinedType(an), \one()> | <an, wf> <- getFreeTypeAnalyses(ftp))
        | tpn <- entities(mlSchema), <fn, ftp> <- mlSchema.attrs[tpn], isFreeTextType(ftp)
    )
    ;
    
    graphEdges = {
        <
            fields[entityType(ent)][frm]<0>,
            fields[entityType(ent)][to]<0>,
            entityType(ent)
            >
        | /graphSpec(edges) := mlSchema, <ent, frm, to> <- edges
    };
    return <fields, graphEdges>;
}

TModel checkQLTree(Tree t, CheckerMLSchema mlSchema, bool debug = false) {
    if (t has top) {
        t = t.top;
    }
    return collectAndSolve(t, config=buildConfig(debug, mlSchema));
}

TModel checkQLTree(Tree t, Schema mlSchema, bool debug = false) 
    = checkQLTree(t, convertModel(mlSchema), debug = debug);
