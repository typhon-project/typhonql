
# TyphonQL: an Evolving Reference Manual

## Introduction



## The Language

### Literal expressions

TyphonQL supports the following literal (constant) expressions:

- Booleans: `true`, `false`
- Integer numbers: `123`, `-34934`
- Strings: `"this is a string value"`
- Floating point numbers: `0.123`, `3.14`, `-0.123e10`, `2324.3434e-23`
- Dates:  `$2020-03-31$`
- Date and time values:  `$2020-03-31T18:08:28.477+00:00$`
- Geographical points: `#point(23.4 343.34)`
- Polygons: `#polygon((23.4 343.34), (2.0 0.0))`;
- Null (indicating absence of a reference or value): `null`

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





# TyphonQL by Example




```typhonML
entity Product {
	name : string[256]
	description : string[256]
	price : int
	productionDate : date
		
	reviews :-> Review."Review.product"[0..*]
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
	reviews :-> Review."Review.user"[0..*]
}

entity Biography{
	content : string[256]
	
	user -> User[1]
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
```

## Well-formedness of TyphonML models

- containment is uni-directional (e.g. inverses of containment cannot be containment)
- containment is not many-to-many (i.e. tree shaped)
- containment is uniquely rooted: every owned entity can be reached from a unique 
path starting from an entity that is not owned




## Realizing references 

TyphonML references support bidirectional navigation over relations between entities through inverses (AKA "opposites").
In the implementation, however, we must choose one particular direction to implement the relation. 
Technically, we could maintain bidirectional relations in both directions, but this would create a lot of redundancy
in the various back-ends, and incur a lot of administrative overhead to maintain referential integrity.

Given a TyphonML model, TyphonQL realizes the "canonical" direction of a relation. Which direction is 
canonical is determined as follows:

If a reference represents containment (ownership), the parent/owner "owns" the reference as well.
So a containment relation R between A and B will be implemented on the side of A. If A and B are both in 
the same SQL database, this results in a foreign key on B, pointing to A. If A is on SQL, but B is 
elsewhere, the reference is realized using a junction table in the database of A.

If both A and B are on MongoDB, the reference is realized by nesting B's directly below A.R.  If A is on MongoDB, 
but B is elsewhere, A will contain (an array) of ids which correspond to the identities of the outside Bs.

If a relation A-R-B is *not* containment, we need a reliable way to determine which of A or B is the "master" entity.
To avoid picking some arbitrary side of such a relation, we require the TyphonML author explicitly indicate the "master" side
of such a relation. This is done by declaring inverses/opposites only on one side of the relation; then *that* side is 
the "derived" side, and the other one the primary/canonical side which will be realized in the back-end.

Consider the following example:
```typhonML
entity A { b -> B }

entity B { a -> A."A.b" }
```

In this case B declares that a is the opposite of A.b, so it won't be implemented. The entity A does not
specify the opposite, so it is the side that will be realized. In the case A resides on SQL, it will be a junction table; 
if A is on Mongo, the cross-reference will be realized using (an array of) id-ref(s). 

As a result, the use of inverses [TODO] will be desugared to using the canonical side:
```
from A a, B b select b where b.a == a.@id
```
Is equivalent to:
```
from A a, B b select b where a.b == b.@id
```


## Querying

Mongo: expression: field op non-field or reverse, but not fields at both sides.


```
from User u, Product p, Review r select u.name, p.name
 where u.reviews == r, p.reviews == r, r.text like "bad"
```


## Manipulating Data


### Insert

Well-formedness of Insert
- no inverses, just canonical relations
- no nested documents (for now)

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

 
 



