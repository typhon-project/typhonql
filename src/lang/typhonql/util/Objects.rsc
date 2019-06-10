module lang::typhonql::util::Objects

import lang::typhonql::Expr;
import lang::typhonql::util::UUID;


alias IdMap = lrel[str name, str entity, str uuid];


@doc{Flatten possibly nested objs to a list of labeled object literals}
list[Obj] flatten({Obj ","}* objs) {
  int i = 0;
  VId newLabel() {
    VId x =[VId]"obj_<i>";
    i += 1;
    return x;
  }
  
  list[Obj] result = [];
  
  // NB: bottom-up is essential here
  bottom-up visit (objs) {
    case (KeyVal)`<Id x>: <EId e> {<{KeyVal ","}* kvs>}`: {
      VId l = newLabel();
      result += [(Obj)`@<VId l> <EId e> {<{KeyVal ","}* kvs>}`]; 
      insert (KeyVal)`<Id x>: <VId l>`;  
    }
    case Obj obj: result += [obj];
  } 
  
  return result;
}

IdMap makeIdMap(list[Obj] objs) 
  = [ <"<vid>", "<entity>", makeUUID()> | (Obj)`@<VId vid> <EId entity> {<{KeyVal ","}* _>}` <- objs ];



