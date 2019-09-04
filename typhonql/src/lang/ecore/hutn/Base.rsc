module lang::ecore::hutn::Base

extend lang::std::Layout;
extend lang::std::Id;

syntax Ref[&Class]
  = Id
  | Loc
  ;
  
syntax Loc = ProtocolChars PathChars;
  
lexical ProtocolChars = [|] URLChars "://" !>> [\t-\n \r \ \u00A0 \u1680 \u2000-\u200A \u202F \u205F \u3000];

lexical PathChars = URLChars [|] ;

lexical URLChars = ![\t-\n \r \  \< |]* ;


lexical Name 
  = @category="Type" ![{]* ![\n\t\r\ {] ;
  
syntax Nav
  = root: "/"
  | field: Nav "/@" Id 
  | index: Nav "." Int
  ;

lexical Bool
  = "true"
  | "false"
  ;

lexical Real
  = [\-]? [0-9]+ [E e] [+ \-]? [0-9]+ 
  | [\-]? [0-9]+ "." !>> "." [0-9]* 
  | [\-]? [0-9]+ "." [0-9]* [E e] [+ \-]? [0-9]+  
  ;


lexical Int
  = [0] !>> [0-9] 
  | [\-]? [1-9] [0-9]* !>> [0-9] 
  ;

lexical Str
  = @category="Constant" "\"" StringCharacter* chars "\"" ;
  
lexical StringCharacter
	= "\\" [\" \\ b f n r t] 
	| UnicodeEscape 
	| ![\" \\ \n\t\r\b\f]
	;
  
lexical UnicodeEscape
  = utf16: "\\" [u] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] 
  | utf32: "\\" [U] (("0" [0-9 A-F a-f]) | "10") [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] [0-9 A-F a-f] // 24 bits 
  | ascii: "\\" [a] [0-7] [0-9A-Fa-f]
  ;
  