module lang::typhonql::Query

extend lang::typhonql::Expr;

syntax Query = "from" {Binding ","}+ bindings "select" {Result ","}+ selected Where? where GroupBy? groupBy OrderBy? orderBy;

syntax Result 
  = Expr!obj!lst expr "as" Id attr
  | VId var "." Id attr // duplicated from Expr
  ;

syntax Binding = EId entity VId var;
  
syntax Where = "where" {Expr ","}+ clauses;

syntax GroupBy = "group" {VId ","}+ vars Having? having;

syntax Having = "having" {Expr ","}+ clauses;

syntax OrderBy = "order" {VId ","}+ vars;
  