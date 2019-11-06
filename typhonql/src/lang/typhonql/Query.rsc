module lang::typhonql::Query

extend lang::typhonql::Expr;

syntax Query 
  = from: "from" {Binding ","}+ bindings "select" {Result ","}+ selected Where? where GroupBy? groupBy OrderBy? orderBy;

syntax Result 
  = Expr!obj!lst expr "as" Id attr
  | Expr expr // only entity path is allowed, but we don't check
  ;

syntax Binding = EId entity VId var;
  
syntax Where = "where" {Expr ","}+ clauses;

syntax GroupBy = "group" {VId ","}+ vars Having? having;

syntax Having = "having" {Expr ","}+ clauses;

syntax OrderBy = "order" {VId ","}+ vars;
  
alias Env = map[str var, str entity];

Env queryEnv(Query q) = queryEnv(q.bindings);

Env queryEnv({Binding ","}+ bs) = ("<x>": "<e>" | (Binding)`<EId e> <VId x>` <- bs );
  
  