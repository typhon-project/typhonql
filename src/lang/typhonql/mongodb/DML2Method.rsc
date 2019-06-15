module lang::typhonql::mongodb::DML2Method

import lang::typhonql::mongodb::DBCollection;
import lang::typhonql::DML;
import lang::typhonql::Expr;
import lang::typhonml::Util;


/*
How to determine whether an entity becomes a collection
or anonymously nested?

I guess if it's contained, and there are no incoming xrefs to it the entity, otherwise, we need a reference identifier
*/

//DBObject obj2dbObj(

