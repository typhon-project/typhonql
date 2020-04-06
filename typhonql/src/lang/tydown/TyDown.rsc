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