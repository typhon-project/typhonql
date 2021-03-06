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

module lang::typhonql::mongodb::DBCollection

import IO;
import List;
import util::Math;
import String;
import DateTime;
import lang::typhonql::util::UUID;
import lang::typhonql::util::Dates;

alias Prop
  = tuple[str name, DBObject val];  
  
data DBObject  
  = object(list[Prop] props)
  | array(list[DBObject] values)
  | \value(value v)
  | mUuid(str uuid)
  | placeholder(str name="") 
  | null()
  ;
  
DBObject pointer2mongo(pointerUuid(str name)) = mUuid(name);
DBObject pointer2mongo(pointerPlaceholder(str name))= DBObject::placeholder(name = name);
  
  
str pp(object(list[Prop] ps)) = "{<intercalate(", ", [ pp(p) | Prop p <- ps ])>}";

str pp(array(list[DBObject] vs)) = "[<intercalate(", ", [ pp(v) | DBObject v <- vs ])>]";

str pp(\value(int i)) = "<i>";


str pp(\value(real r)) = "<r>";

str pp(\value(str s)) = "\"<strEscape(s)>\"";

str pp(\value(bool b)) = "<b>";

str pp(\value(datetime d)) {
    epoch = epochMilliSeconds(d);
    if (onlyDate(d)) {
        return pp(object([<"$timestamp", object([
            <"t", \value(round(epoch / 1000))>,
            <"i", \value(epoch >= 0 ? 1 : -1)>
            ])
       >]));
    }
    return pp(object([<"$date", object([<"$numberLong", \value("<epoch>")>])>]));
}

str pp(mUuid(val)) = pp(object([
        <"$binary", object([
            <"base64", \value(uuidToBase64(val))>,
            <"subType", \value("04")>
        ])>
    ]));

str pp(null()) = "null";

str pp(placeholder(name = str x)) = "\"${<x>}\"";

str pp(<str f, DBObject v>) = "\"<f>\": <pp(v)>";  
  
  
default str pp(DBObject v) { throw "Unsupported DBObject json value `<v>`"; }
  
str strEscape(str s)
  = escape(s, ("\n": "\\n", "\t": "\\t", "\r": "\\r", "\\": "\\\\", "\"": "\\\"" ));  
    
// I'm skipping all readpreference, DBEncode, Object and *Options things  

// NB: the names, arities and types of the match the methods names and params in Java exactly,
// so we can use reflection to map a CollMethod to an actual method call on DBCollection.
// where ...varargs become keyword params, List<...> list, and array[] also list
  
data CollMethod
  = find(DBObject query)
  | find(DBObject query, DBObject projection)
  | insertOne(DBObject doc)
  | findAndUpdateOne(DBObject query, DBObject update)
  ;  
  
// Apparently this API below does not correspond to the one we use
// the above subset is the one we'll use for now.  
data CollMethod
  = aggregate(DBObject firstOp, list[DBObject] additionalOps = [])
  | aggregate(list[DBObject] pipeline)	
  | count()	
  | count(DBObject query)	
  | createIndex(DBObject keys)	
  | createIndex(DBObject keys, DBObject options)	
  | createIndex(DBObject keys, str name)	
  | createIndex(DBObject keys, str name, bool unique)	
  | createIndex(str name)	
  | distinct(str fieldName)	
  | distinct(str fieldName, DBObject query)	
  | drop()	
  | dropIndex(DBObject index)	
  | dropIndex(str indexName)	
  | dropIndexes()	
  | dropIndexes(str indexName)	
  | find()	
  | find(DBObject query)	
  | find(DBObject query, DBObject projection)	
  | find(DBObject query, DBObject projection, int numToSkip, int batchSize)	
  | findAndModify(DBObject query, DBObject update)	
  | findAndModify(DBObject query, DBObject sort, DBObject update)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, bool bypassDocumentValidation, int maxTime, TimeUnit maxTimeUnit)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, bool bypassDocumentValidation, int maxTime, TimeUnit maxTimeUnit, WriteConcern writeConcern)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, int maxTime, TimeUnit maxTimeUnit)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, int maxTime, TimeUnit maxTimeUnit, WriteConcern writeConcern)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, WriteConcern writeConcern)	
  | findAndRemove(DBObject query)	
  | findOne()	
  | findOne(DBObject query)	
  | findOne(DBObject query, DBObject projection)	
  | findOne(DBObject query, DBObject projection, DBObject sort)	
  | getCollection(str name)	
  | getCount()	
  | getCount(DBObject query)	
  | getCount(DBObject query, DBObject projection)	
  | getCount(DBObject query, DBObject projection, int limit, int skip)	
  | group(DBObject key, DBObject cond, DBObject initial, str reduce)	
  | group(DBObject key, DBObject cond, DBObject initial, str reduce, str finalize)	
  | \insert(list[DBObject] documents)	
  | \insert(list[DBObject] documents, WriteConcern writeConcern)	
  | \insert(DBObject document, WriteConcern writeConcern)	
  | \insert(WriteConcern writeConcern, list[DBObject] documents = [])	
  | \insert(list[DBObject] documents)	
  | remove(DBObject query)	
  | remove(DBObject query, WriteConcern writeConcern)	
  | rename(str newName)	
  | rename(str newName, bool dropTarget)	
  | save(DBObject document)	
  | save(DBObject document, WriteConcern writeConcern)	
  | update(DBObject query, DBObject update)	
  | update(DBObject query, DBObject update, bool upsert, bool multi)	
  | update(DBObject query, DBObject update, bool upsert, bool multi, WriteConcern aWriteConcern)	
  | updateMulti(DBObject query, DBObject update)
  ;

data WriteConcern
  = ACKNOWLEDGED()
  | JOURNALED()
  | MAJORITY()
  | W1()
  | W2()
  | W3();

data ReadConcern
  = DEFAULT()
  | LINEARIZABLE()
  | LOCAL()
  | MAJORITY()
  | SNAPSHOT()
  ;

data TimeUnit
  = DAYS() | HOURS() | MICROSECONDS() | MILLISECONDS() | MINUTES() | NANOSECONDS() | SECONDS();	
  
