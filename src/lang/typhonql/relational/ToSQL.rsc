module lang::typhonql::relational::ToSQL



/*

create table `<Entity>` (
  `typhon_id` char(36) not null, 
  
  
  primary key (`typhon_id`), 
  
);

Foreign keys

create table `...` (

<owner>_id char(36),
    FOREIGN KEY (<owner>_id)
        REFERENCES owner(typhon_id)
        ON DELETE CASCADE
)

*/

/*

rel[str, Cardinality, name, name, Cardinality, str]

# Mapping

## Types

Date
String
int
Blob

## Relations

:-> [1]     put foreign in target table, add cascade delete
            or put foreign key in parent, add cascade delete, and foreign key in child and cascade delete (???)
:-> [0..1]     (and assume parent is always 1; no containment from multiple things)
:-> [0..*]

-> [1]      always use junction table, unless inverse of containment
-> [0..1]
-> [0..*]




*/