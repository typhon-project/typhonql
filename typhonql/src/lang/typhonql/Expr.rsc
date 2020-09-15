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

module lang::typhonql::Expr

extend lang::std::Layout;
extend lang::std::Id;

syntax Expr
  = attr: VId var "." {Id "."}+  attrs
  | var: VId var
  | placeHolder: PlaceHolder ph
  | key: VId var "." "@id"
  | @category="Number" \int: Int intValue
  | @category="Constant" \str: Str strValue
  | @category="Number" \real: Real realValue
  | @category="Constant" \dt: DateTime dtValue
  | @category="Constant" point: Point pointValue
  | @category="Constant" polygon: Polygon polygonValue
  | \bool: Bool boolValue
  | uuid: UUID uuidValue
  | blob: BlobPointer blobPointerValue
  | bracket "(" Expr arg ")"
  | obj: Obj objValue // for use in insert and allow nesting of objects
  | custom: Custom customValue // for use in insert and allow nesting of custom data types
  //| lst: "[" {Obj ","}* entries "]" 
  | refLst: "[" {PlaceHolderOrUUID ","}* refs "]" // plus to not make amb with empy lst 
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
    | non-assoc reaching: VId lhsI Reaching reaching VId rhsI
  )
  > left intersect: Expr lhs "&" Expr rhs
  > left and: Expr lhs "&&" Expr rhs
  > left or: Expr lhs "||" Expr rhs
  ;
  
  
syntax Reaching = reach: "-[" VId edge ReachingBound? bound "]-\>";

syntax ReachingBound 
	= lowerUpper: "," Expr lower ".." Expr upper
	| lower: "," Expr lower ".."
	| upper: "," ".." Expr upper
	| exact: "," Expr bound
	;

// Entity Ids  
lexical EId = Id entityName \ Primitives;
  
keyword Primitives
  = "int" | "bigint" | "string" | "bool" | "text" | "float" 
  | "blob" | "freetext" | "date" | "datetime" | "point" | "polygon" ;
  

syntax Point
  = singlePoint: "#point" "(" XY coordinate ")"
  ;

syntax XY
  = coordinate: Real x Real y;

syntax Polygon
  = shape: "#polygon" "(" {Segment ","}* segments ")" 
  ;
  
syntax Segment
  = line: "(" {XY ","}* points ")";


// Variable Ids
lexical VId = Id variableName \ "true" \ "false" \ "null";

// extend Id for customdata type inlined representation
lexical Id
  = Id "$" {Id "$"}+
  ;

lexical Bool = "true" | "false";

syntax Obj = literal: Label? labelOpt EId entity "{" {KeyVal ","}* keyVals "}";

syntax Custom = literal: EId typ "(" {KeyVal ","}* keyVals ")";
  
lexical Label = "@" VId label;
  
syntax KeyVal 
  = keyValue: Id key ":" Expr value
  // needed for insert/update from workingset so that uuids can be used as identities
  | storedKey: "@id" ":" Expr value 
  ;

lexical PlaceHolderOrUUID = PlaceHolder ph | UUID uuid;

lexical PlaceHolder = "??" Id name;

// textual encoding of reference
lexical UUID = @category="Identifier" "#" UUIDPart part;
lexical UUIDPart = [\-a-zA-Z0-9]+ !>> [\-a-zA-Z0-9];
lexical BlobPointer = @category="Identifier" "#blob:" UUIDPart part;

// todo: escaping etc.
lexical Str = [\"] StrChar* contents [\"];

lexical StrChar
	= escaped: "\\" [\" \\ b f n r t] 
	| rest: ![\" \\]+ !>> ![\" \\]
	;

lexical Int
  = [1-9][0-9]* !>> [0-9]
  | [0]
  ;
  
lexical Real
  = Int "." [0]* !>> "0" Int?
  | Int "." [0]* !>> "0" Int? [eE] [\-]? Int;
  
syntax DateTime
	= date: JustDate date
	| full: DateAndTime dateTime ;

lexical JustDate
	= "$" DatePart "$";
	
lexical DatePart = Year y "-" Month m "-" Day d;
	
lexical Year = [0-9] [0-9] [0-9] [0-9];
lexical Month = [0-1] [0-9];
lexical Day = [0-3] [0-9];
	
lexical DateAndTime = "$" DatePart "T" TimePart ZoneOffset? "$";

lexical ZoneOffset 
	= [+ \-] Hour h ":" Minute m
	| "Z" 
	;

lexical TimePart = Hour h ":" Minute m ":" Second s Millisecond? ms;
lexical Hour = [0-2] [0-9];
lexical Minute = [0-5] [0-9];
lexical Second = [0-5] [0-9];
lexical Millisecond = [.] [0-9] ([0-9] [0-9]?)?;