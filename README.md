# Run in eclipse
- Import the `typhonql` as maven projects in eclipse. Let eclipse install the right maven connector plugins.

# Building with maven (for example update sites)

```
(cd typhonql-bundler && mvn clean install)
mvn clean package
```

Technically the bundler only has to be run on every version bump of the bundler. (which is needed for new maven dependencies)

# Documentation

The language is documented here: [TODO](link).

# Feature support

In the tables below we will try to give an overview of feature support of the current master branch.

| Icon | Meaning |
|:---:|--|
| 🌑 | not implemented |
| 🌒 | initial implementation, expect bugs |
| 🌓 | partially implemented (for example not on all backends) |
| 🌔 | fully implemented, might be some bugs left |
| 🌕 | finished |

## Types

Basic primitive types.

| Feature | Syntax | Backend | Remarks |
|----|:---:|:---:|---|
| `int` | :full_moon: | :full_moon: | |
| `bigint` | :first_quarter_moon: | :first_quarter_moon: | |
| `string(maxSize)` | :first_quarter_moon: | :first_quarter_moon: | currently `str` exists, but this will be renamed to `text`, and `string` will get a length field |
| `text` | :waxing_gibbous_moon: | :full_moon: | in current syntax this is still called `str` |
| `point` | :new_moon: | :new_moon: | |
| `point` | :new_moon: | :new_moon: | |
| `bool` | :full_moon: | :full_moon: | |
| `float` | :full_moon: | :waxing_gibbous_moon: | |
| `blob` | :new_moon: | :new_moon: | We have to decide on a syntax for blobs |
| `freetext[Id+]` | :waxing_gibbous_moon: | :new_moon: | Syntax is almost finished, still requiring some work with ML & NLP teams |
| `date` | :full_moon: | :first_quarter_moon: | |
| `datetime` | :full_moon: | :first_quarter_moon: | |
| Custom data types | :waxing_gibbous_moon: | :waxing_crescent_moon: | |

## Relations

TODO: make table about different kind of relations in relation to cross database operations

## Expressions

| Feature | Syntax | Backend | Remarks |
|----|:---:|:---:|---|
| "nested" field access (`a.b.c`) | 🌕 | 🌔 | |
| placeholders (`??<name>`) | 🌕 | 🌔 | |
| lists (`[..]`) | 🌕 | 🌔 | only usable for relations |
| positive `+` & negative `-` | 🌕 | 🌔 | if backends supports it |
| math operations (`*+/-`) | 🌕 | ? | TODO: check support |
| comparisons  (`==` and friends) | 🌕 | ? | TODO: check support|
| boolean operations (`&&` and `\|\|`) | 🌕 | 🌔 | |
| containment `x in y` | 🌕 | 🌓 | currently doesn't work form the inverse side |
| text compare `x like y` | 🌕 | ? | TODO: check support |

## Backends

| Backend | Support | Remarks |
| --- | :--: | --- |
| MariaDB | :waxing_gibbous_moon: | Currently not using indexes on important columns |
| MariaDB clusters | :new_moon: | Have to talk with DL team what the influence will be |
| MongoDB | :full_moon: | |
| Cassandra | :new_moon: | |
| Neo4J | :new_moon: | |

## Generic features

| Feature | Support | Remarks |
| --- | :--: | --- |
| Query across different backends | :waxing_gibbous_moon: | |
| Query validation | :waxing_gibbous_moon: | Syntax is validated and checked against the ML model |
| Query type checking in IDE | :new_moon: | |
| Query optimization | :waxing_crescent_moon: | We try to get where clauses on the correct backend |
| Unicode Support | :waxing_gibbous_moon: | It should be possible to use unicode anywhere. Collation is currently fixed (we have to think about extending this in ML if needed) |
| DAL/Generated API | :new_moon: | |
| Navigation based queries (path, reachability, transitive closure) | :new_moon: | |
| Transactions | :new_moon: | unclear if we can add decent support for this |
| Parametrized/Bulk queries | :waxing_crescent_moon: | Currently doesn't provide a lot of performance benefit, but can in the future |
| DDL Operations | :first_quarter_moon: | |
| Operations on `freetext` attributes | :new_moon: | Working with NLP team to get this integrated |
