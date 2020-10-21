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

module lang::typhonql::check::Test

import lang::typhonml::TyphonML;
import lang::typhonql::TDBC;
import lang::typhonql::check::Checker;
extend analysis::typepal::TestFramework;

TModel checkQLTree(Tree e, CheckerMLSchema schema, bool debug) = checkQLTree(e, schema, debug = debug);

test bool runExprTest(bool debug = false)
    = runTests([|project://typhonql/src/lang/typhonql/check/expressions.ttl|], 
            #Expr, 
            TModel (t) { return checkQLTree(t, <(), {}>, debug); }, 
            runName = "QL Expressions");
            
            
CheckerMLSchema queriesModel = <(
    entityType("User"): (
        "name": <stringType(), \one()>,
        "changes": <entityType("User"), zero_many()>
    )
), {}>;
            
test bool runQueryTest(bool debug = false) 
    = runTests([|project://typhonql/src/lang/typhonql/check/queries.ttl|], 
            #Query, 
            TModel (t) { return checkQLTree(t, queriesModel, debug); }, 
            runName = "QL Queries");

test bool runDMLTest(bool debug = false) 
    = runTests([|project://typhonql/src/lang/typhonql/check/dml.ttl|], 
            #Statement, 
            TModel (t) { return checkQLTree(t, queriesModel, debug); }, 
            runName = "QL DML");
