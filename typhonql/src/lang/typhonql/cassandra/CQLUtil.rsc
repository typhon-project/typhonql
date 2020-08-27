module lang::typhonql::cassandra::CQLUtil

import lang::typhonql::cassandra::CQL;
 
CQLExpr pointer2cql(pointerUuid(str name)) = cTerm(cUUID(name));
CQLExpr pointer2cql(pointerPlaceholder(str name))= cBindMarker(name = name);