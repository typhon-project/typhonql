module lang::typhonql::check::Test

import lang::typhonml::TyphonML;
import lang::typhonql::check::Checker;
extend analysis::typepal::TestFramework;

TModel checkQLTree(Expr e, bool debug) = checkQLTree(e, Model([], [], []), debug = debug);

test bool runExprTest(bool debug = false)
    = runTests([|project://typhonql/src/lang/typhonql/check/expressions.ttl|], 
            #Expr, 
            TModel (t) { return checkQLTree(t, debug); }, 
            runName = "QL Expressions");