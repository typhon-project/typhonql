module lang::typhonql::util::UUID

/*

All identity management is done by TyphonQL using UUIDs.
This module define a single function to create such UUIDs.

*/

@javaClass{lang.typhonql.util.MakeUUID}
java str makeUUID();

@javaClass{lang.typhonql.util.MakeUUID}
java str hashUUID(str key);


@javaClass{lang.typhonql.util.MakeUUID}
java str uuidToBase64(str uuid);

@javaClass{lang.typhonql.util.MakeUUID}
java str base64Encode(str contents);