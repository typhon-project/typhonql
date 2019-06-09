module lang::typhonql::Query

extend lang::typhonql::Expr;

syntax Query = Query: "from" {Binding ","}+ bindings "select" {Expr ","}+ selected Where? where GroupBy? groupBy OrderBy? orderBy;

syntax Binding = Binding: EId entity VId var;
  
syntax Where = Where: "where" {Expr ","}+ clauses;

syntax GroupBy = GroupBy: "group" {VId ","}+ vars Having? having;

syntax Having = Having: "having" {Expr ","}+ clauses;

syntax OrderBy = OrderBy: "order" {VId ","}+ vars;
  