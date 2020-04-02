# Typhon - REST Data Acces Layer
## Proposal

This document describes a REST layer that can be uses to perform CRUD operations on Typhon entities.

## Design considerations

* Endpoints begin with `/[Entity]/`, where `Entity` corresponds to the entity type.
* The entity representation is a JSON object whose fields correspond to the entity attributes, including the uuid and the entity type, e.g. `{"type": "User", id: "#918df0bc", "name": "\"Bob\"", "age": "19" }`
* N-ary relations are represented by a JSON array of strings, each of it corresponding to the related entity uuid, e.g. `"users" : [ "#918df0bc", "#7ba3681b"]`.
* 1-ary relations are represented by a JSON string corresponding to the related entity uuid, e.g. `"user" : "#918df0bc"`.
* Fields have to be encoded like a query, so a string value should have nested qoutes, and a UUID should be prefixed with a pound (`#`).
* It should be possible to generate corresponding swagger files based on an ML model.


## Operations

| Operation| Endpoint  | Method  | Description |
|---|---|---|---|
| Create entity | /[Entity] | POST  | Create a new entity |
| Get entity | /[Entity]/[uuid]  | GET  | Get the representation of an existing entity |
| Update entity | /[Entity]/[uuid]  | PATCH  | Update an existing entity |
| Delete entity | /[Entity]/[uuid]  | DELETE  | Delete an existing entity |

## Examples
 
### Create entity

POST `/User/`

**HTTP status codes**

201 Created
404 Entity not found 
500 Error

**Request:**

```
{ "type": "User", "name": "\"Patrick\"", "age": "39" }
```

**Result:**

The HTTP header of the result contains link to newly created entity. E.g.:

```
Location: http://polystore.somewhere.com/crud/User/b58f8848
```

The corresponding body:

```
{ "@id": "b58f8848" }
```
 
### Get entity

GET `/User/b58f8848`

**HTTP status codes**

200 OK
404 Entity not found 
500 Error

**Result:**

```
{ "@id": "b58f8848", "name": "\"Patrick\"", "age": "39" }
```
 
### Update entity

PATCH `/User/b58f8848`

**HTTP status codes**

200 OK
404 Entity not found 
500 Error

**Request:**

```
{ "age": "40" }
```

### Delete entity

DELETE `/User/b58f8848`

**HTTP status codes**

200 OK
404 Entity not found
500 Error
