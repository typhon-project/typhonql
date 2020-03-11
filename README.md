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
|---|--|
|:new_moon: | not implemented |
|:waxing_crescent_moon: | initial implementation, expect bugs |
|:first_quarter_moon: | partially implemented (for example not on all backends) |
|:waxing_gibbous_moon: | fully implemented, might be some bugs left |
|:full_moon: | finished |

## Types

| Feature | Syntax | Backend |
|----|---|---|
| `int` | :full_moon: | :full_moon: |
| `bigint` | :first_quarter_moon: | :first_quarter_moon: |
| `string(maxSize)` | :first_quarter_moon: | :first_quarter_moon: |
| `text` | :waxing_crescent_moon: | :waxing_crescent_moon: |
| `point` | :new_moon: | :new_moon: |
| `point` | :new_moon: | :new_moon: |
| `bool` | :full_moon: | :full_moon: |
| `float` | :full_moon: | :waxing_gibbous_moon: |
| `blob` | :new_moon: | :new_moon: |
| `freetext[Id+]` | :waxing_gibbous_moon: | :new_moon: |
| `date` | :full_moon: | :first_quarter_moon: |
| `datetime` | :full_moon: | :first_quarter_moon: |
