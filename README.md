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
| `int` | 🌕 | 🌕 | |
| `bigint` | 🌓 | 🌓 | |
| `string(maxSize)` | 🌓 | 🌓 | currently `str` exists, but this will be renamed to `text`, and `string` will get a length field |
| `text` | 🌔 | 🌕 | in current syntax this is still called `str` |
| `point` | 🌑 | 🌑 | |
| `point` | 🌑 | 🌑 | |
| `bool` | 🌕 | 🌕 | |
| `float` | 🌕 | 🌔 | |
| `blob` | 🌑 | 🌑 | We have to decide on a syntax for blobs |
| `freetext[Id+]` | 🌔 | 🌑 | Syntax is almost finished, still requiring some work with ML & NLP teams |
| `date` | 🌕 | 🌓 | |
| `datetime` | 🌕 | 🌓 | |
| Custom data types | 🌔 | 🌒 | |

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
| containment `x in y` | 🌕 | 🌓 | currently doesn't work from the inverse side |
| text compare `x like y` | 🌕 | ? | TODO: check support |

## Backends

| Backend | Support | Remarks |
| --- | :--: | --- |
| MariaDB | 🌔 | Currently not using indexes on important columns |
| MariaDB clusters | 🌑 | Have to talk with DL team what the influence will be |
| MongoDB | 🌕 | |
| Cassandra | 🌑 | |
| Neo4J | 🌑 | |

## Generic features

| Feature | Support | Remarks |
| --- | :--: | --- |
| Query across different backends | 🌔 | |
| Query validation | 🌔 | Syntax is validated and checked against the ML model |
| Query type checking in IDE | 🌑 | |
| Query optimization | 🌒 | We try to get where clauses on the correct backend |
| Unicode Support | 🌔 | It should be possible to use unicode anywhere. Collation is currently fixed (we have to think about extending this in ML if needed) |
| DAL/Generated API | 🌑 | |
| Navigation based queries (path, reachability, transitive closure) | 🌑 | |
| Transactions | 🌑 | unclear if we can add decent support for this |
| Parametrized/Bulk queries | 🌒 | Currently doesn't provide a lot of performance benefit, but can in the future |
| DDL Operations | 🌓 | |
| Operations on `freetext` attributes | 🌑 | Working with NLP team to get this integrated |
