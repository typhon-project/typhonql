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