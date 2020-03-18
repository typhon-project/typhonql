


## Problem

Consider the following example with tables in SQL and a collection in MongoDB:

Table `User`

```
@id | name | age
----+------+----
#p  |Pablo | 30
#d  |Davy  | 20
```

Junction table `Review.author-User.reviews`

```
R.a|U.r
---+---
#r1|#p
#r2|#d
#r3|#d
```

Review collection

```
{_id: #r1, author: #p, text: "", stars: 3}
{_id: #r2, author: #d, text: "Bad", stars: 0}
{_id: #r3, author: #d, text: "Good", stars: 5}
```

Now consider we have the following query:

from User u, Review r select u.name, r.stars where u.reviews == r, r.text == ""

Should result in (including @id's)

- all persons in the result of the SQL query
  (signature: Person.u.name \times Person.u.reviews)

```
   @id|name |U.r
   ---+-----+---
   #p |Pablo|#r1
   #d |Davy |#r2
   #d |Davy |#r3
```


- all reviews in the result of MongoDB find with empty text
  where _id matches up with Person.u.reviews

```
  {_id: #r1, stars: 3}
```

The final result should be

```
name | stars
-----+------
Pablo| 3
```

So this means that, for every row of the SQL result that we execute
the mongo query for (and that does not return an empty set), we need
to add a result to the final result. IOW: we *cannot* do it after the
fact. The "join" on the review id (U.r & _id) happens within the
for-loops of the iteration architecture. We don't want to loop *again*
over the individual result sets to do the join "in Java".



## Direct-style iteration architecture

For every database back-end, we have an iterator object, which returns
(partial) records/tuples, keyed by `Entity.Var.field` labels, which
might end-up in the final result, and used to do interpolation into
queries (using `${}` etc.).

The session architecture basically interprets the script, which
contains "steps" executed on particular back-ends.

So we may assume we have MongoDBEngine and MariaDBEngine etc., which
have methods to execute a query that returns an iterable thing of the
above record/tuple structure.

Without loss of generality, we may assume each step is of the
following form: `step(Backend, QueryString, map[str, Label])`. For
now, we may further assume, that there's only a single step *per
back-end* (not per back-end *type*, but per back-end). The script is
ordered. Let's say we have steps S0 to Sn.

```
for (Record r0: Engine_S0.exec(interpolate(S0.query, S0.params, []))) {
  for (Record r1: Engine_S1.exec(interpolate(S1.query, S1.params, [r0])) {
     ...
        for (Record rn: Engine_Sn.exec(interpolate(Sn-1.query, Sn-1.params, [r0, ..., rn-1]))) {
           appendResultRow([r0, ..., rn])
         }
     ...
   }
}
```

The interpolate function substitutes parameters the query string,
taking values, from the list of currently produced records.

`appendResultRow` should project out the relevant `Entity.Var.Field`
components from r0 to rn that are required for constructing the final
result table, the signature of which derives from the "select" clause
of the original TyphonQL query.


## Inversion of control

Currently, the script is interpreted on top of the Session abstraction
from within Rascal. Pending the possibility of interpreting the script
directly in Java, the above structure needs to be inverted, in the
sense that the for-loops, are not "driving" the interpretation.
IIUC, this is also how it is now implemented using recursion. 

Below pseudo Java code modeling a Session object that constructs the same control-flow lazily, by using the session-like API method that we have now (the ones that are invoked from the closures passed into the Rascal `Session` type). 

```
class Session {
  private List<Consumer<List<Record>>> script = [];

  public void engine_S0_exec(String q, Params params) {
    int nxt = script.size() + 1;
    script.add((List<Record> row) -> {
       for (Record myR: Engine_S0.exec(interpolate(q, params, row))) {
          script.get(nxt).call(row ++ myRecord);
       }
    });
  }

  public void engine_S1_exec(...) { /* similar */ }

  ...

  List<List<Record>> read(ColSpec columns) {
    List<List<Record>> result = [];
    script.add((List<Record> row) -> {
       result.append(project(row, columns));
    });
    script.get(0).call([]);
    return result;
  }
}
```
  
NB: this could be probably be made "nicer" with a proper tail
recursive continuation structure instead of the list of closures, but
for now I think this should be sufficient.

The `script` field contains a sequence of closures that each invoke
the next one passing in results that have been generated, until the
last closure is reached which constructs the result table.

The `read` method should be called last with a specification of the
actual `Entity.Var.Field` labels that are derived from the select
clause of the original query. Hence, this information should be
generated into the script on the Rascal side.

Note that id-generation, would be simply another method in such a
class, populating the map with generated id, where `interpolate` would
access that.