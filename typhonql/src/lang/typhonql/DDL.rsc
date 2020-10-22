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

module lang::typhonql::DDL

extend lang::typhonql::Expr;

syntax Statement
  = \createEntity: "create" EId eId "at" Id db
  | \createAttribute: "create" EId eId "." Id name ":" Type typ
  | \createAttributeKeyValue: "create" EId eId "." Id name ":" Type typ "forKV" Id kvDb
  | \createRelation: "create" EId eId "." Id relation Inverse? inverse Arrow EId target "[" CardinalityEnd lower ".." CardinalityEnd upper "]"
  | \createIndex: "create" "index" Id indexName "for" EId eId "."  "{" {Id ","}+ attributes "}" 
  | \dropEntity: "drop" EId eId
  | \dropAttribute: "drop" "attribute" EId eId "." Id name
  | \dropRelation: "drop" "relation" EId eId "." Id name
  | \dropIndex: "drop" "index" EId eId "." Id indexName
  | \renameEntity: "rename" EId eId "to" EId newEntityName
  | \renameAttribute: "rename" "attribute" EId eId "." Id name"to" Id newName  
  | \renameRelation: "rename" "relation" EId eId  "." Id name "to" Id newName  
  ;
  
syntax Inverse = inverseId: "(" Id inverse ")";

syntax Type
  = intType: "int" // the 32bit int
  | bigIntType: "bigint"  // 64bit
  | stringType: "string" "(" Nat maxSize ")"
  | textType: "text"
  | pointType: "point" // To check
  | polygonType: "polygon" // To check 
  | boolType: "bool" 
  | floatType: "float" // IEEE float 
  | blobType: "blob" 
  | freeTextType: "freetext" "[" {Id ","}+ nlpFeatures "]"
  | dateType: "date" 
  | dateTimeType: "datetime"
  ;

lexical Nat = [0-9]+ !>> [0-9];

lexical Arrow = "-\>" | ":-\>";

lexical CardinalityEnd = [0-1] | "*";
  
bool isDDL(Statement s) = s is \createEntity || s is \createAttribute || s is \createRelation
  || s is \dropEntity || s is \dropAttribute || s is \dropRelation || s is \renameAttribute || s is \renameRelation
  || s is \createIndex || s is \dropIndex || s is \createAttributeKeyValue ; 
