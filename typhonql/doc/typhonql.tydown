
# TyphonQL: an Evolving User Manual

## Introduction

TyphonQL is a query language and data-manipulation language (DML) to access polystores (federations of 
different kinds of database back-ends, relational, document, key-value etc.) while at the same time
abstracting as much as possible from how the data is actually stored.

Executing TyphonQL queries is parameterized by a TyphonML model, which provides the logical data schema in the
form of an object-oriented information model. A TyphonML model declares entities with primitively-typed attributes, 
and bi-directional (many-valued) relations (which can be containment/ownership) relations. 

TyphonQL is designed to allow the query writer to think at the level of TyphonML entities as much as possible. 
With TyphonQL one does not manipulate tables, graphs, documents, or key-value pairs, but sets of objects which 
may have relations to each other, and which conform to the entity types declared in the TyphonML model. 

The present document aims to describe the TyphonQL in sufficient detail for end-users of the language. 
Thus, it is not a formal reference document, but rather a short overview, touching upon the most common and 
most quirky features in equal amount.

The next section presents an abstract overview of the language, and after we present the language using numerous examples.

*NB*: like TyphonQL itself, this manual, is work-in-progress. It describes how the designers of TyphonQL 
(Tijs van der Storm, Pablo Inostroza, Davy Landman) expect the language to work, -- there might be bugs.


## The Language

This section provides a cursory overview of the language.

### Literal expressions

TyphonQL supports the following literal (constant) expressions:

- Booleans: `true`, `false`
- Integer numbers: `123`, `-34934`
- Strings: `"this is a string value"`
- Floating point numbers: `0.123`, `3.14`, `-0.123e10`, `2324.3434e-23`
- Dates:  `$2020-03-31$`
- Date and time values:  `$2020-03-31T18:08:28.477+00:00$`
- Geographical points: `#point(23.4 343.34)`
- Polygons: `#polygon((0.1 1.0, 2.0 0.0, 3.0 3.0, 0.1 1.0))`;
- Null (indicating absence of a reference or value): `null`
- Blob-pointers: `#blob:2ed99a8e-5259-4efd-8cb4-66748d52e8a1`

Furthermore, TyphonQL supports syntax for dealing with objects (instances of entity types):

- Object literals (tagged with the entity type, in this case `Person`): `Person {name: "Pablo", age: 30, reviews: [#879b4559-f590-48ea-968c-ff3b69ec5363, #23275eec-4746-4f23-a854-660160cafed2]}`
- Reference values (pointers), represented as UUIDs: `#879b4559-f590-48ea-968c-ff3b69ec5363`
- Collections of pointers to objects:  `[#8bc3f0a0-5cf4-42e5-a664-0617feb2d400, #23275eec-4746-4f23-a854-660160cafed2, #879b4559-f590-48ea-968c-ff3b69ec5363]`

Object literals are used as argument to insert statements, and (lists of) references are used in 
both insert and update statements to create links/relations between objects. 
In the future we might support nesting of object literals and within-insert symbolic cross referencing
to manipulate complete object graphs all at once.      

### Other expressions

Select queries as well as update and delete statements use expressions to filter results and find objects to operate on 
respectively. For instance, a from-select query specifies a number of result expressions and conditions in the where-clause.
Update and delete find the object(s) to be update resp. deleted using similar conditions in a where-clause.

TyphonQL supports the following non-literal expressions:

- Attribute or relation access: `entity.field`
- Accessing the identity of an object: `entity.@id`
- Boolean operators: `!exp` (negation), `exp1 && exp2` (conjunction), `exp1 || exp2` (disjunction)
- Arithmetic operators: `exp1 * exp2`, `exp1 / exp2`, `exp1 + exp2`, `exp1 - exp2`
- Comparison operators: `exp1 == exp2`, `exp1 != exp1`, `exp1 > exp2`, `exp1 >= exp2`, etc.

The prefix and infix operators follow the precedence levels of Java-like languages.

To be implemented:
- member operator: `exp1 in exp2`
- textual match operator: `exp1 like exp2`

### Geographical expressions


```notTyphonQL
pt1 = point(1.3,2.5)
pt2 = point(3.5,4.6)
pg1 = polygon([
  [point(0, 0), pt1, point(1,1), pt2, point(0,0)]
])
pg2 = polygon([
  [point(3,0), pt1, point(2,2), pt2, point(3,2)]
])
```
*(note: pseudo QL syntax to make it a bit more readable)*

distance in meters:
  
- two points: `distance(pt1, pt2)` 
- one point and closest edge of polygon: `distance(pt1, pg2)`

containment:
- point inside a polygon: `pt1 in pg2`
- polygon fully inside another polygon: `pg1 in pg2`

overlap:
- polygon partially overlaps another polygon: `pg1 & pg2`


*note*: on mongodb backends distance is limited to the where query and only in presence of a comparison operator. Cassandra and neo4j don't support geo operations.

### Graph expressions
If two entities are related to each other through an entity stored in a graph database, it is possible to use the reachability expression:

`entity1 -[edgeEntity, lower..upper]-> entity2`

- `entity1` and `entity2` are the ids of entities that can be stored in any backend
- `edgeEntity` is the id of the entity stored as an edge in a graph database
- `lower` and `upper` are expressions that represents the bounds for the _number of hops_ one wants to execute from `entity1`. By ommiting one or both of them, we get different semantics explained through the following examples.

Example 1:  `person1 -[friendOf, 2..3]-> person2` -> Find friends of `person1` using at least 2 jumps and at most 3 jumps. Notice that this expression will ignore the direct friends of `person1`.

Example 2:  `person1 -[friendOf, 1..]-> person2` -> Find friends of `person1` using at least 1 jump, without constraining how many jumps can be used.

Example 3:  `person1 -[friendOf, ..3]-> person2` -> Find friends of `person1` using at most 3 jumps. By default the lower limit would be 1.

Example 4:  `person1 -[friendOf]-> person2` -> Find friends of `person1` using at least 1 jumps and without constraining the number of jumps. This expression computes the transitive closure of `friendOf` for the set `{ person1 }`.


### Blobs

Blobs are handled in a special way, during insertion/update you have to send them as a pointer to a blob: `#blob:UUID` (and pass along the contents of the blob to the API in a seperate field).
While selecting them, you get a base64 encoded version of the blob. It is not possible to do any operations on them, they are opaque.

### Queries

Queries follow the tradition of SQL queries, except that the select and from parts are swapped. 
A basic query thus has the form of "*from* bindings *select* results *where* conditions".
Bindings consist of a list of "Entity Variable" pairs, separated by comma, which introduce the scope of the query.
Results is a list of expressions (separated by commas) that will make up the final result of the query.
The where-clause is optional, but if present it consists of a list of expressions (separated by commas)
filtering the result set. 

For now, in results the only allowed expressions are `x` (an entity variable introduced in the bindings), `x.@id`, and `x.f` 
(attribute or relation access). 

### DML

The general form of the insert statement is "*insert* Entity { assignments }".
The entity is the type of the object to be inserted as defined in the TyphonML statement.
The assignments are bindings of the form "attrOrRelation: expression". 
The TyphonQL type checker will check that all assignments are correctly typed according
the TyphonML model, including multiplicity constraints. 

Update and delete statements specify the objects to work on via where-clauses.
For instance, update has the form "*update* Entity x *where* conditions *set* { assignments }".
The assignments are the same as in insert, except that for many-valued relations, they can specify
additions ("relation +: expression") and removals ("relation -: expression").

Delete has the form "*delete* Entity x *where* conditions", which will delete all entities of type Entity satisfying
the conditions in the where-clause. 

All three DML statements ensure (as much as possible) that relational integrity is preserved, 
even across database back-ends. In particular
this means:

- creating resp. breaking a relation between entities entail creating resp. breaking the inverse link as well 
(if so declared in the TyphonML model)
- deleting an object will delete all objects "owned" by it via containment relations (cascading delete).

Cascading delete of contained object is currently limited to one hop across database boundaries. 
In other words, if a sequence of containment relations alternatingly cross multiple database back-ends
the cascade is only performed for the first relation.

## NLP

If the type of a field is `freetext` you have extra subfields available during select queries. Nothing special happens during insertion, but depending on the configered nlp analysis for this field, you have extra fields available. The table below lists all of the custom fields.


| Analysis | Fieldname | type |
|-----|----|----|
| PhraseExtraction | PhraseExtraction.Token | text |
| PhraseExtraction | PhraseExtraction.end | int |
| PhraseExtraction | PhraseExtraction.begin | int |
| POSTagging | POSTagging.end | int |
| POSTagging | POSTagging.begin | int |
| POSTagging | POSTagging.PosTag | text |
| POSTagging | POSTagging.PosValue | text |
| RelationExtraction | RelationExtraction.TargetEntity.NamedEntity | text |
| RelationExtraction | RelationExtraction.RelationName | text |
| RelationExtraction | RelationExtraction.TargetEntity.begin | int |
| RelationExtraction | RelationExtraction.TargetEntity.end | int |
| RelationExtraction | RelationExtraction.end | int |
| RelationExtraction | RelationExtraction.begin | int |
| RelationExtraction | RelationExtraction.SourceEntity.NamedEntity | text |
| RelationExtraction | RelationExtraction.SourceEntity.end | int |
| RelationExtraction | RelationExtraction.SourceEntity.begin | int |
| nGramExtraction | nGramExtraction.NgramType | text |
| nGramExtraction | nGramExtraction.begin | int |
| nGramExtraction | nGramExtraction.end | int |
| ParagraphSegmentation | ParagraphSegmentation.end | int |
| ParagraphSegmentation | ParagraphSegmentation.begin | int |
| ParagraphSegmentation | ParagraphSegmentation.Paragraph | text |
| Tokenisation | Tokenisation.Token | text |
| Tokenisation | Tokenisation.end | int |
| Tokenisation | Tokenisation.begin | int |
| TermExtraction | TermExtraction.end | int |
| TermExtraction | TermExtraction.WeightedToken | int |
| TermExtraction | TermExtraction.TargetEntity.NamedEntity | int |
| TermExtraction | TermExtraction.begin | int |
| TermExtraction | TermExtraction.TargetEntity.begin | int |
| TermExtraction | TermExtraction.TargetEntity.end | int |
| Chunking | Chunking.begin | int |
| Chunking | Chunking.end | int |
| Chunking | Chunking.PosAnnotation.PosValue | text |
| Chunking | Chunking.PosAnnotation.end | int |
| Chunking | Chunking.TokenAnnotation.begin | int |
| Chunking | Chunking.TokenAnnotation.end | int |
| Chunking | Chunking.PosAnnotation.PosTag | text |
| Chunking | Chunking.PosAnnotation.begin | int |
| Chunking | Chunking.TokenAnnotation.Token | text |
| Chunking | Chunking.Label | text |
| NamedEntityRecognition | NamedEntityRecognition.NamedEntity | text |
| NamedEntityRecognition | NamedEntityRecognition.begin | int |
| NamedEntityRecognition | NamedEntityRecognition.GeoCode | point |
| NamedEntityRecognition | NamedEntityRecognition.WordToken | text |
| NamedEntityRecognition | NamedEntityRecognition.end | int |
| Stemming | Stemming.begin | int |
| Stemming | Stemming.end | int |
| Stemming | Stemming.Stem | text |
| Lemmatisation | Lemmatisation.begin | int |
| Lemmatisation | Lemmatisation.end | int |
| Lemmatisation | Lemmatisation.Lemma | text |
| DependencyParsing | DependencyParsing.DependencyName | text |
| DependencyParsing | DependencyParsing.TargetEntity.NamedEntity | text |
| DependencyParsing | DependencyParsing.TargetEntity.begin | int |
| DependencyParsing | DependencyParsing.TargetEntity.end | int |
| DependencyParsing | DependencyParsing.begin | int |
| DependencyParsing | DependencyParsing.SourceEntity.begin | int |
| DependencyParsing | DependencyParsing.SourceEntity.end | int |
| DependencyParsing | DependencyParsing.end | int |
| DependencyParsing | DependencyParsing.SourceEntity.NamedEntity | text |
| SentenceSegmentation | SentenceSegmentation.Sentence | text |
| SentenceSegmentation | SentenceSegmentation.begin | int |
| SentenceSegmentation | SentenceSegmentation.end | int |
| SentimentAnalysis | SentimentAnalysis.SentimentLabel | text |
| SentimentAnalysis | SentimentAnalysis.Sentiment | int |
| CoreferenceResolution | RelationExtraction.Anaphor.begin | int |
| CoreferenceResolution | RelationExtraction.Anaphor.Token | text |
| CoreferenceResolution | RelationExtraction.Anaphor.end | int |
| CoreferenceResolution | CoreferenceResolution.Antecedent.end | int |
| CoreferenceResolution | CoreferenceResolution.begin | int |
| CoreferenceResolution | CoreferenceResolution.Antecedent.begin | int |
| CoreferenceResolution | CoreferenceResolution.end | int |
| CoreferenceResolution | CoreferenceResolution.Antecedent.Token | text |

### Date time & timezones

Every datebase handles date-time, time zones and time offsets differently. For typhon ql we picked a scheme that would be correct for most use cases, and we could support for all of the backends.

We store and normalize all date times in UTC/Zulu time zone. If you send a date time with an offset, we apply that offset and store it in UTC time. If you send a date time without an offset, we use the time zone of the QL server (that is configurable via the `TZ` environment flag) to translate it to UTC.

On querying a date-time field, you will always get back the UTC version. Client libraries can use that to convert it back to a display format if required. If you are dealing with an application with multiple time zones, it's a good idea to store the zone id (like `Europe/Amsterdam`) in a separate field next to the date-time.

# TyphonQL by Example

## Introduction

In this section we will illustrate TyphonQL using numerous examples. 
The example queries and DML statements should be understood in the context
of an example TyphonML, which is shown below. 

```typhonML
entity Product {
	name : string[256]
	description : string[256]
	price : int
	productionDate : date
	reviews :-> Review."Review.product"[0..*]
	wish :-> Wish."Wish.product"[1]
}

entity Review {
	content: text
	product -> Product[1]
	user -> User[1]
}

entity User {
	name : string[256]
	address: string[256]
	biography :-> Biography[0..1]
	reviews -> Review."Review.user"[0..*]
	wish :-> Wish."Wish.user"[1]
}

entity Biography{
	content : string[256]
	user -> User[1]
}

entity Wish {
	intensity: int	
	user -> User[1]
	product -> Product[1]
}

relationaldb Inventory {
	tables{ 
	  table { UserDB : User }
      table { ProductDB : Product }
	}
}

documentdb Reviews {
	collections{
	  Review : Review
	  Biography : Biography
	}
}

graphdb Wishes {
	edges {
		edge Wish {
			from "Wish.user"
			to "Wish.product"
		}
	}
}
```

Entities Product and User are deployed to an SQL database (MariaDB), called Inventory; the Review and Biography entities are stored on a (MongoDB) document-store called Reviews; and the Wish entity is stored on a (Neo4J) graph database.

Products own a number of Reviews ("deleting a product will delete associated reviews as well") via
the relation `reviews`.
The ownership link can be traversed from the `product` reference in Reviews because of the opposite
declaration on `reviews`.

Reviews are also authored by users, which is modeled by the `reviews` relation on the User entity.
This relation is not a containment relation, because an entity can only be owned by a single
entity at one point in time. User biographies however are owned by User entities via the `biography` relation.

A Wish relates one user to one product, holding a value for the "intensity" of this relation. Entities that are
stored in graph databases have a number of constraints, as they represent edges in this kind of backends. Wish 
must have exactly two related entities with cardinality 1, and the opposite relation might be declared in the 
related entities, as long as they represent containment and have cardinality one (see `wish` relation in Product
and User). In other words, removing any of the entities that correspond to the vertices should also remoce
the "edge" entity. The directionality of the relation is established in the database mapping, particularly, in the graphdb
section, where we see which relation represent the source and which one the target inside the graph database.

## Well-formedness of TyphonML models

TyphonQL assumes TyphonML models are well-formed in the following ways:

- all entities are are placed on a database back-end
- containment is uni-directional (e.g. inverses of containment cannot be containment)
- containment is not many-to-many (i.e. tree shaped)
- containment is uniquely rooted: every owned entity can be reached from a unique 
path starting from an entity that is not owned




## Realizing references 

TyphonML references support bidirectional navigation over relations between entities through inverses (AKA "opposites").
In other words it is possible to navigate across a *single* relation in two ways. 
In order to support this in the implementation of TyphonQL, such bidirectional relations are realized
in the back-ends in both directions. TyphonQL ensures that updates to a relation are always mirrored
in the other direction according to the opposite declaration(s).
This means that how you navigate across a relation (from which direction) may have different consequences
at the level of the implementation.

The only exceptions to this rule are:
- a containment relation within SQL is always modeled using a *single* foreign key from child to parent
- a cross-reference relation within SQL is modeled using a *single* junction table (representing both directions).



## Querying

Selecting all users:
```
from User u select u
```
This will return all the attributes of all users (but *excluding* references to other entities).

Selecting specific attributes of users:
```
from User u select u.name
```
This will return the identities of the users paired with their name.

Selecting a specific relation:
```
from User u select u.reviews
```
This will return pairs of user identity and review identity.
If a user has no reviews, it's identity will be paired with `null`.


Filtering on a specific attribute:
```
from User u select u where u.name == "Pablo"
```

A complex query across database boundaries: find all user and product name pairs
for which a user has written a review containing the word "bad".
```
from User u, Product p, Review r select u.name, p.name
 where u.reviews == r, p.reviews == r, r.text like "bad"
```

Note the use of "==" even for many-valued references.
You may wonder why not use the `x in y` operator for "joining" on collections; this has to do
with how relational back-ends deal with multiplicity and would complicate the implementation
considerably.

### Aggregation Support

TyphonQL currently supports the usual aggregation operators `count`, `sum`, `max`, `min`, and `avg`,
to be used in combination with the group-construct.

For instance, to count the number of reviews per user:
```
from User u 
select u.name, count(u.reviews) as revCount
group u.name
```

_NB_: *ALL* aggregation expressions (e.g. `count(u.reviews)`) need to be aliased with a variable name using "as".

If you want to consider the whole entity as the only group you may omit the "group"-clause, e.g.:
```
from User u 
select count(u.@id) as cnt
```
Counts the number of unique users.

Aggregated values can be constrained using the having-clause:
```
from User u 
select u.name, count(u.reviews) as revCount
group u.name
having revCount > 5
```
This selects all users (and their review counts) that have written more than five reviews.

The aggregation component of TyphonQL also supports limit- and order-clauses for, respectively, limiting the size of 
the result set, and sorting it. These can be used in combination with aggregation (group-by) or without.

For instance:
```
from User u 
select u.name, count(u.reviews) as revCount
group u.name
order revCount desc
```
sorts the previous query in descending order by review count.
The "desc" modifier can also be omitted, in which case it amounts to using "asc" for ascending order.

To get the most prolific reviewer, one could write:
```
from User u 
select u.name, count(u.reviews) as revCount
group u.name
order revCount desc
limit 1
```


## Manipulating Data


TODO: mention that parents should pre-exist kids ("children cannot exist without parents").
With insert: custom data type value must be fully specified,
but in updates, you can partially update sub-fields.


```
insert User { name: "John Smith", age: 30 }
```


```
insert User { name: "John Smith", age: 30, cards: [#a129feec-4b92-4ab2-9ef5-d276a7566f56] }
```

```
insert CreditCard { number: "1762376287", expires:  $2020-02-21T14:03:45.274+00:00$ }
```

The following is not allowed, because owner is an inverse.
```
insert CreditCard { 
  number: "1762376287", 
  expires:  $2020-02-21T14:03:45.274+00:00$,
  owner: #ff704edc-5d85-470b-9ed4-fb8761bbe93a
}
```


Alternative is:
```
insert CreditCard { 
  number: "1762376287", 
  expires:  $2020-02-21T14:03:45.274+00:00$
}
```

and then:
```
update User u where u.@id == #ff704edc-5d85-470b-9ed4-fb8761bbe93a
set { cards +: [#the-id-of-the-new-creditcard] }
```


Or, (better), inserting into owner directly:



### Update

Well-formedness of Update
- you cannot update @id fields
- no nested object literals



Updating simple-valued attributes

```
update User u where u.name == "John Smith" set { age: 30 }
```

Updating custom data types: TODO.

Setting a relation:

```
update Review r where r.@id == #13245f43-634f-46bf-a73d-6bd30865f5d4
  set { author: #a129feec-4b92-4ab2-9ef5-d276a7566f56 }
``` 

This is equivalent to:

```
update User u where u.@id == #a129feec-4b92-4ab2-9ef5-d276a7566f56
  set { reviews +: [#13245f43-634f-46bf-a73d-6bd30865f5d4] }
```

// is this possible? Shouldn't review already have an owner? i.e. the author?


Setting a many-valued relation:

```
update User u where u.name == "John Smith"
  set { cards: [#a129feec-4b92-4ab2-9ef5-d276a7566f56] }
``` 

Adding:

```
update User u where u.name == "John Smith"
  set { cards +: [#a129feec-4b92-4ab2-9ef5-d276a7566f56] }
``` 

Removing
```
update User u where u.name == "John Smith"
  set { cards -: [#a129feec-4b92-4ab2-9ef5-d276a7566f56] }
``` 


### Delete

- cascade to owned things, but only one hop across database boundaries.

## Placeholders


```
update User u where u.@id == ?
  set { cards +: [#a129feec-4b92-4ab2-9ef5-d276a7566f56] }
``` 

Named placeholders:

```
update User u where u.@id == ??param
  set { cards +: [#a129feec-4b92-4ab2-9ef5-d276a7566f56] }
``` 

## HTTP API

To execute queries outside of the TyphonQL IDE, the Typhon Polystore offers an HTTP API. This section describes how to invoke it, we only describe the section of the Polystore API related to TyphonQL.

### Reset Database

In case you need to start from fresh: 

`GET http://polystore-api/api/resetdatabases`

### Select queries

Post the query as a json object to: 

`POST http://polystore-api/api/query`

Body: 

```json
{
  "query": "from User u select u"
}
```

Note that you have to make sure to correctly encode is as a json string, any language with a json library will take care of this.

### Insert/Update/Delete queries

Post the command as a json object to:

`POST http://polystore-api/api/update`

Body:

```json
{
  "query": "insert User { name : \"John\", age: 35 }"
}
```

#### Inserting/updating blobs 
If you want to insert a new blob, you have to send along the contents of the blob separately from the query.


```json
{
  "query": "update User u where u.name==\"John\" set { image: #blob:ecbbb3c4-6c5f-4ef0-bce4-58b847a82222 }",
  "blobs": {
    "ecbbb3c4-6c5f-4ef0-bce4-58b847a82222": "eW91IGdldCBhIGNvb2tpZQ==" // base64 encode of the blob contents
  }
}
```

#### Parameterized queries

For both ease of writing and performance, it's possible to generate send a single query, where placeholders will be replaced by a list of bindings. This makes it possible to send multiple queries in a single command.


```json
{
  "query": "insert User { @id: ??id, name: ??uname, age: ??uage }",
  "parameterNames": ["id", "uname", "uage"],
  "parameterTypes": ["uuid", "string", "int"],
  "boundValues": [
    ["beefc0b2-0393-4b73-951c-7243ee849275", "John Smith", "20"],
    ["52001d98-05f2-4832-b653-6077a4db05a7", "Smith John", "1"]
  ]
}
```

Some remarks about this api:

- You have to give the names for the parameters, their typhon types, and then a 2d __string__ array, with rows that are bound to the parameters, in the same order.
- The syntax of the values is the same as the output of a query. You do not have to encode the values as QL literals (for example, a uuid doesn't have to be prefixed with `#`, and a string doesn't require double escaping).
- Valid types are:
  - `int`
  - `bigint`
  - `float`
  - `string`
  - `bool`
  - `text`
  - `uuid`
  - `date`
  - `datetime`
  - `point`
  - `polygon`
  - `blob` (for these you _do_ have to use the ql literal: `#blob:uuid...`)
- You can combine this with the blobs field.
- Any json libary should be able to generate these objects
- We encode numbers as string, since json only supports doubles
 

 
 



