module lang::typhonql::Expr

extend lang::std::Layout;
extend lang::std::Id;

syntax Expr
  = attr: VId var "." {Id "."}+  attrs
  | var: VId var
  | placeHolder: PlaceHolder
  | key: VId var "." "@id"
  | @category="Number" \int: Int intValue
  | @category="Constant" \str: Str strValue
  | @category="Number" \real: Real realValue
  | @category="Constant" \dt: DateTime dtValue
  | @category="Constant" point: Point pointValue
  | @category="Constant" polygon: Polygon polygonValue
  | \bool: Bool boolValue
  | uuid: UUID uuidValue
  | bracket "(" Expr arg ")"
  | obj: Obj objValue // for use in insert and allow nesting of objects
  | custom: Custom customValue // for use in insert and allow nesting of custom data types
  //| lst: "[" {Obj ","}* entries "]" 
  | refLst: "[" {UUID ","}* refs "]" // plus to not make amb with empy lst 
  | null: "null"
  | pos: "+" Expr arg
  | neg: "-" Expr arg
  | call: VId name "(" {Expr ","}* args ")"
  | not: "!" Expr arg
  > left (
      left mul: Expr lhs "*" Expr rhs
    | left div: Expr lhs "/" Expr rhs
  )
  > left (
      left add: Expr lhs "+" Expr rhs
    | left sub: Expr lhs "-" Expr rhs
  )
  > non-assoc (
      non-assoc hashjoin: Expr lhs "#join" Expr rhs
    | non-assoc eq: Expr lhs "==" Expr rhs
    | non-assoc neq: Expr lhs "!=" Expr rhs
    | non-assoc geq: Expr lhs "\>=" Expr rhs
    | non-assoc leq: Expr lhs "\<=" Expr rhs
    | non-assoc lt: Expr lhs "\<" Expr rhs
    | non-assoc gt: Expr lhs "\>" Expr rhs
    | non-assoc \in: Expr lhs "in" Expr rhs
    | non-assoc like: Expr lhs "like" Expr rhs
  )
  > left and: Expr lhs "&&" Expr rhs
  > left or: Expr lhs "||" Expr rhs
  ;
  

// Entity Ids  
lexical EId = Id entityName \ Primitives;
  
keyword Primitives
  = "int" | "bigint" | "string" | "bool" | "text" | "float" 
  | "blob" | "freetext" | "date" | "datetime" | "point" | "polygon" ;
  

syntax Point
  = singlePoint: "#point" "(" XY ")"
  ;

syntax XY
  = coordinate: Real Real;

syntax Polygon
  = shape: "#polygon" "(" {Segment ","}* ")" 
  ;
  
syntax Segment
  = line: "(" {XY ","}* ")";


// Variable Ids
lexical VId = Id variableName \ "true" \ "false" \ "null";

lexical Bool = "true" | "false";

syntax Obj = literal: Label? labelOpt EId entity "{" {KeyVal ","}* keyVals "}";

syntax Custom = literal: EId typ "(" {KeyVal ","}* keyVals ")";
  
lexical Label = "@" VId label;
  
syntax KeyVal 
  = keyValue: Id key ":" Expr value
  // needed for insert/update from workingset so that uuids can be used as identities
  | storedKey: "@id" ":" Expr value 
  ;

lexical PlaceHolder = "??" Id name;

// textual encoding of reference
lexical UUID = @category="Identifier"  "#"[\-a-zA-Z0-9]+ !>> [\-a-zA-Z0-9];

// todo: escaping etc.
lexical Str = [\"] ![\"]* [\"];

lexical Int
  = [1-9][0-9]* !>> [0-9]
  | [0]
  ;
  
lexical Real
  = Int "." [0]* !>> "0" Int?
  | Int "." [0]* !>> "0" Int? [eE] [\-]? Int;
  
syntax DateTime
	= date: JustDate date
	| time: JustTime  time
	| full: DateAndTime dateTime ;

lexical JustDate
	= "$" DatePart "$";
	
lexical DatePart
	= [0-9] [0-9] [0-9] [0-9] "-" [0-1] [0-9] "-" [0-3] [0-9] 
	| [0-9] [0-9] [0-9] [0-9] [0-1] [0-9] [0-3] [0-9] ;
	
	
lexical JustTime
	= "$T" TimePartNoTZ !>> [+\-] "$"
	| "$T" TimePartNoTZ TimeZonePart "$"
	;
	
lexical DateAndTime
	= "$" DatePart "T" TimePartNoTZ !>> [+\-] "$"
	| "$" DatePart "T" TimePartNoTZ TimeZonePart "$";

lexical TimeZonePart
	= [+ \-] [0-1] [0-9] ":" [0-5] [0-9] 
	| "Z" 
	| [+ \-] [0-1] [0-9] 
	| [+ \-] [0-1] [0-9] [0-5] [0-9] 
	;

lexical TimePartNoTZ
	= [0-2] [0-9] [0-5] [0-9] [0-5] [0-9] ([, .] [0-9] ([0-9] [0-9]?)?)? 
	| [0-2] [0-9] ":" [0-5] [0-9] ":" [0-5] [0-9] ([, .] [0-9] ([0-9] [0-9]?)?)? 
	;