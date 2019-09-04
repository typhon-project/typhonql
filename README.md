# Run in eclipse
- install typhonml plugin (see word doc)
- Import the `typhonql` as maven projects in eclipse. Let eclipse install the right maven connector plugins.

# Building with maven (for example update sites)

```
cd typhonql-bundler
mvn clean install 
cd ..
mvn clean package
```

Technically the bundler only has to be run on every version bump of the bundler. (which is needed for new maven dependencies)
