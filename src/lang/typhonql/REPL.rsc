module lang::typhonql::REPL

extend lang::typhonql::DML;
extend lang::typhonql::Query;


import lang::typhonml::Util;
import lang::typhonql::DML2SQL;
import lang::typhonql::Select2SQL;
import lang::typhonql::Schema2SQL;
import lang::typhonql::SQL2Text;



import util::REPL;
import Message;
import ParseTree;


start syntax Command
  = Query
  | Statement 
  | "load" Id  // currently directly from typhonml dir
  ;
  

  
void typhonREPL(loc schemaRoot = |cwd:///|) {
  Schema s = schema({}, {});
  
  CommandResult handler(str line) {
    try {
      start[Command] cmd = parse(#start[Command], line, |prompt:///|);
      
      try {
        switch (cmd.top) {
          case (Command)`load <Id m>`: {
            loc l = |project://typhonql/src/lang/typhonml/<"<m>">.model|;
            s = loadSchema(l);
            return commandResult(pp(schema2sql(s)));
          }
          case (Command)`<Query q>`: 
            return commandResult(pp(select2sql(q, s)));

          case (Command)`<Statement d>`:
            return commandResult(pp(dml2sql(d, s)));
        }
      }
      catch value v: {
        return commandResult("<v>", messages = [message("Error", l)]);
      }

    }
    catch ParseError(loc l): {
      return commandResult("", messages = [message("Parse error", l)]);
    }
    
  }
  
  Completion completor(str line, int cursor) {
    return <cursor, []>;
  }
  
  

  startREPL(repl("TyphonQL", "Welcome to TyphonQL", "\>", |home:///.typhonql|, handler, completor));
}