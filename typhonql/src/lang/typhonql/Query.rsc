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

module lang::typhonql::Query

extend lang::typhonql::Expr;

syntax Query 
  = from: "from" {Binding ","}+ bindings "select" {Result ","}+ selected 
      Where? where 
      Agg* aggClauses;
      

syntax Result 
  = aliassed: Expr!obj!lst expr "as" VId attr
  | normal: Expr expr // only entity path is allowed, but we don't check
  ;

syntax Binding = variableBinding: EId entity VId var;
  
syntax Where = whereClause: "where" {Expr ","}+ clauses;


syntax Agg
  = groupClause: "group" {Expr ","}+ exprs
  | havingClause: "having" {Expr ","}+ exprs
  | orderClause: "order" {Expr ","}+ exprs Dir dir
  | limitClause: "limit" Expr expr
  ;
  
lexical Dir
  = "asc"
  | "desc"
  | /* asc */
  ;
  
//syntax GroupBy = groupClause: "group" {Expr ","}+ exprs Having? having;
//
//syntax Having = havingClause: "having" {Expr ","}+ clauses;
//
//syntax OrderBy = orderClause: "order" {Expr ","}+ exprs;
//
//syntax Limit = limitClause: "limit" Expr expr;
  
alias Env = map[str var, str entity];

Env queryEnv(Query q) = queryEnv(q.bindings);

Env queryEnv({Binding ","}+ bs) = ("<x>": "<e>" | (Binding)`<EId e> <VId x>` <- bs );
  
  
