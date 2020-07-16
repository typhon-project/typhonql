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

module lang::typhonql::ast::JavaASTCompiler

import lang::typhonql::TDBC;
import ParseTree;

import lang::typhonql::ast::TreeToAST;
import lang::rascal::grammar::ParserGenerator;
import lang::rascal::grammar::definition::Modules;
import lang::rascal::grammar::definition::Parameters;

import IO;
import String;
import ValueIO;  
import Grammar;

void main(loc target = |project://typhonql-ast/src/generated/java/|, str namespace = "engineering.swat.typhonql.ast") {
  gr = grammar(#start[Request]);
  println("Generating parser");
  generateParser(gr, target, namespace);
  println("Generating ASTs");
  generateASTs(gr, target, namespace);
}

void generateParser(Grammar g, loc target, str namespace) {
  source = newGenerate(namespace, "TyphonQLParser", g);
  writeFile(getFilePath(target, namespace, "TyphonQLParser.java"), source);
}

loc getFilePath(loc root, str namespace, str fileName)
    = (root + replaceAll(namespace, ".", "/")) + fileName;


void generateASTs(Grammar g, loc target, str namespace) {
  g = expandParameterizedSymbols(g);
  grammarToJavaAPI(target + replaceAll(namespace, ".", "/"), namespace, g);
}
