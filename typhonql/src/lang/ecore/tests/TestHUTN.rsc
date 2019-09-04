module lang::ecore::tests::TestHUTN


import lang::ecore::hutn::Ecore2HUTN;
import lang::ecore::hutn::Model2HUTN;
import lang::ecore::hutn::HUTN2Model;

import lang::ecore::text::Grammar2Ecore;
import lang::ecore::text::Tree2Model;

import lang::ecore::diff::Diff;

import lang::ecore::tests::StmHUTN;
import lang::ecore::tests::Syntax;
import lang::ecore::tests::MetaModel;

import lang::ecore::Ecore;

import IO;
import ParseTree;

void setup() {
  writeMyFsmHUTNGrammar();
}

void testHUTNBackAndForth() {
  stms = [ l | loc l <- |project://rascal-ecore/src/lang/ecore/tests/|.ls
             , l.extension in {"old", "new"}];
  int fails = 0;
  int errs = 0;
  for (loc stm <- stms) {
    if (!testToAndFromHUTN(stm)) {
       fails += 1;
    }
  } 
  println("<fails> failed; <errs> exceptions; <size(stms) - fails - errs> success");
}


bool testToAndFromHUTN(loc stm) {
  pt = parse(#lang::ecore::tests::Syntax::Machine, stm);
  lang::ecore::tests::MetaModel::Machine m = tree2model(#lang::ecore::tests::MetaModel::Machine, pt);
  str src = model2hutn(#lang::ecore::tests::MetaModel::Machine, m);
  //println(src);
  hutnLoc = stm[extension="<stm.extension>.myfsm_hutn"];
  writeFile(hutnLoc, src);
  hutn = parseMyfsm(src, hutnLoc);
  m2 = hutn2model(#lang::ecore::tests::MetaModel::Machine, hutn, base = stm);
  //iprintln(m2);
  d = diff(#lang::ecore::tests::MetaModel::Machine, m, m2);
  iprintln(d);
  return d.edits == [];
}



