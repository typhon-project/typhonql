module lang::typhonql::mongodb::Method

// abstract syntax of MongoDB's collection methods

@Obsolete
data Method(bool many = false)
  = find(str coll, Doc pattern, set[Proj] projections = {})
  | \insert(str coll, Doc doc)
  | update(str coll, Doc pattern, list[Updates] updates)
  | delete(str coll, Doc pattern)
  ;
  
  
//http://mongodb.github.io/mongo-java-driver/3.10/javadoc/index.html?com/mongodb/client/model/package-summary.html

// http://mongodb.github.io/mongo-java-driver/3.10/javadoc/com/mongodb/client/model/Updates.html  
  
data Update
  = inc(str field, int val)
  | \set(str field, Doc doc)
  | unset(str field)
  | max(str field, int val)
  | min(str field, int val)
  | mul(str field, int val)
  | rename(str field, str newName)
  | currentDate(str field, Type \type)
  | bit(str field, BitOp op)
  | push(str field, Doc doc)
  | pushEach(str field, Doc lst)
  | pushEachSlice(str field, Doc lst, int slice)
  | pushEachPosition(str field, Doc lst, int position)
  | addToSet(str field, Doc doc)
  | popLast(str field)
  | popFirst(str field)
  | pull(str field, Doc pattern)
  | pullAll(str field, Doc lst)
  ;
  

data BitOp
  = and(int val)
  | or(int val)
  | xor(int val)
  ;
 
  
data Proj
  = field(str name, bool suppress = false)
  | expr(); // todo
  

data Doc
  = obj(map[str, Doc] props)
  | lst(list[Doc] elts)
  | val(value val)
  | gt(Doc arg)
  | lt(Doc arg)
  | gte(Doc arg)
  | lte(Doc arg)
  | \in(Doc arg)
  | \nin(Doc arg) 
  | elemMatch(Doc arg)
  | or(list[Doc] args)
  | regex(str pattern)
  | \type(Type \type)
  | textSearch(str strValue)
  | size(int intVal)
  | exists(bool flag)
  | not(Doc arg)
  | empty()
  ;
  
data Type
  = string()
  | number()
  | array()
  | object()
  | date()
  | timestamp()
  ;  
