module lang::typhonql::Query

extend lang::typhonql::Expr;

syntax Query 
  = from: "from" {Binding ","}+ bindings "select" {Result ","}+ selected Where? where GroupBy? groupBy OrderBy? orderBy;

syntax Result 
  = aliassed: Expr!obj!lst expr "as" Id attr
  | normal: Expr expr // only entity path is allowed, but we don't check
  ;

syntax Binding = variableBinding: EId entity VId var;
  
syntax Where = whereClause: "where" {Expr ","}+ clauses;

syntax GroupBy = groupClause: "group" {Expr ","}+ exprs Having? having;

syntax Having = havingClause: "having" {Expr ","}+ clauses;

syntax OrderBy = orderClause: "order" {Expr ","}+ exprs;
  
alias Env = map[str var, str entity];

Env queryEnv(Query q) = queryEnv(q.bindings);

Env queryEnv({Binding ","}+ bs) = ("<x>": "<e>" | (Binding)`<EId e> <VId x>` <- bs );
  
  