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

module lang::tydown::TyDown

extend lang::typhonql::TDBC;

start syntax TyDown
  = Element*
  ;
  
lexical Word
  = word: Text
  | ws: [\ \t]+ !>> [\ \t]
  | exp: [`] Expr [`]  
  | req: [`] Request [`]
  ;  

lexical Words
  = Word+
  ;
  
lexical Text
  = ![#\>\ \t\r\n`]+ !>> ![#\>\ \t\r\n`]
  ;

syntax Element
  = @category="H1" h1: ^ "#" Words $
  | @category="H2" h2: ^ "##" Words $
  | @category="H3" h3: ^ "###" Words $
  | line: ^ [#`\>⇨≫⚠\ \t] !<< Words $
  | code: QQQ Request+ QQQ
  | otherCode: QQQOther Stuff QQQ
  | request: ^ [\>] Request
  | @category="Result" resultOutput: "⇨" ![\n\r]* [\n] 
  | @category="StdOut" stdoutOutput: ^ "≫" ![\n\r]* [\n]
  | @category="StdErr" stderrOutput: ^ "⚠" ![\n\r]* [\n]
  ; 
  
lexical Stuff
  = @category="OtherCode" ![`]* !>> ![`]
  ; 
   
lexical QQQ
  = ^ [`][`][`];
  
lexical QQQOther
  = ^ [`][`][`] Id;
