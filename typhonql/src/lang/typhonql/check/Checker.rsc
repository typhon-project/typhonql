module lang::typhonql::check::Checker

extend analysis::typepal::TypePal;
extend analysis::typepal::TestFramework;

extend lang::typhonql::DML;
extend lang::typhonql::Query;

data AType
    = intType()
    | bigintType()
    | stringType()
    | textType()
    | pointType()
    | polygonType()
    | boolType()
    | floatType()
    | blobType()
    | freeTextType(list[str] nlpFeatures)
    | dateType()
    | dateTimeType()
    ;
    
