#Typhon - REST Data Acces Layer
## Proposal

This document describes a REST layer that can be uses to perform CRUD operations on Typhon entities.

## Design considerations

* Endpoints begin with `/[Entity]/`, where `Entity` corresponds to the entity type.
* The entity representation is a JSON object whose fields correspond to the entity attributes, including the uuid and the entity type, e.g. `{"type": "User", id: "#918df0bc", "name": "\"Bob\"", "age": "19" }`
* N-ary relations are represented by a JSON array of strings, each of it corresponding to the related entity uuid, e.g. `"users" : [ "#918df0bc", "#7ba3681b"]`.
* 1-ary relations are represented by a JSON string corresponding to the related entity uuid, e.g. `"user" : "#918df0bc"`.


## Operations

| Operation| Endpoint  | Method  | Description |
|---|---|---|---|---|
| List entities | /[Entity] | GET  | List all entities (within a fixed limit)  | 
| Create entity | /[Entity] | POST  | Create a new entity  |  /User | 
| Get entity | /[Entity]/[uuid]  | GET  | Get the representation of an existing entity 
| Update entity | /[Entity]/[uuid]  | PATCH  | Update an existing entity 
| Delete entity | /[Entity]/[uuid]  | DELETE  | Delete an existing entity 

## Examples

### List entities

GET `/User/`

**Result:**

```
[{ "type": "User", id: "#918df0bc", "name": "\"Bob\"", "age": "19" },
 { "type": "User", id: "#7ba3681b", "name": "\"Steven\"", "age": "29", 
   "birthDate": "$2001-01-12$"}]
```
 
### Create entity

POST `/User/`

**Request:**

```
{ "type": "User", "name": "\"Patrick\"", "age": "39" }
```

**Result:**

```
{ "uuid": "#b58f8848" },
```
 
### Get entity

GET `/User/b58f8848`

**Result:**

```
{ "type": "User", "name": "\"Patrick\"", "age": "39" }
```
 
### Update entity

PATCH `/User/b58f8848`

**Request:**

```
{ "age": "40" }
```

**Result:**

```
{ "type": "User", "name": "\"Patrick\"", "age": "40" }
```

### Delete entity

DELETE `/User/b58f8848`

**Result:**

```
{ "result": "ok" }
```
