module lang::typhonql::attic::SessionExample

alias Session = tuple[
    void (str resultName, str query, rel[str param, str resultSet, str fieldName] bindings) execute,
    str (str resultName) read,
    void () close
];

@reflect
@javaClass{lang.typhonql.attic.SessionExample}
java Session newSession();