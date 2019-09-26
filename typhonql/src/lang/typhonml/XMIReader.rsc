module lang::typhonml::XMIReader

import lang::xml::IO;
import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::ecore::Refs;

import IO;
import Node;
import Type;

void smokeTest() {
  str xmi = readFile(|project://typhonql/src/newmydb4.xmi|);
  node n = readXML(xmi);
  m = xmiNode2Model(n);
  iprintln(m);
  iprintln(model2schema(m));
}


Model xmiNode2Model(node n) {  
  Realm realm = newRealm();
  
  list[Database] dbs = [];
  list[DataType] dts = [];
  
  str get(node n, str name) = x 
    when str x := getKeywordParameters(n)[name];
  
  map[str, DataType] typeMap = ();
  map[str, Relation] relMap = ();
  
  void ensureEntity(str path) {
    if (path notin typeMap) {
      typeMap[path] = DataType(realm.new(#Entity, Entity("", [], [], [])));
    }
  }
  
  void ensurePrimitive(str path) {
    if (path notin typeMap) {
      typeMap[path] = DataType(realm.new(#PrimitiveDataType, PrimitiveDataType("")));
    }
  }
  
  void ensureRel(str path) {
    if (path notin relMap) {
      relMap[path] = realm.new(#Relation, Relation("", zero_one()));
    }
  }
  
  if ("Model"(list[node] kids) := n) {

    for (xdb:"databases"(list[node] xelts) <- kids) {
      switch (get(xdb, "type")) {
        case "typhonml:RelationalDB": {
          tbls = [];
          for (xtbl:"tables"(_) <- xelts) {
            tbl = realm.new(#Table, Table(get(xtbl, "name")));
            ep = get(xtbl, "entity");
            ensureEntity(ep);
            tbl.entity = referTo(#Entity, typeMap[ep].entity);
            tbls += [tbl];
          }
          
          dbs += [ realm.new(#Database, Database(RelationalDB(get(xdb, "name"), tbls)))];
        }
        
        case "typhonml:DocumentDB": {
          colls = [];
          for (xcoll:"collections"(_) <- xelts) {
            coll = realm.new(#Collection, Collection(get(xcoll, "name")));
            ep = get(xcoll, "entity");
            ensureEntity(ep);
            coll.entity = referTo(#Entity, typeMap[ep].entity);
            colls += [coll];
          }
          
          dbs += [ realm.new(#Database, Database(DocumentDB(get(xdb, "name"), colls))) ];
        }
        
        default:
          throw "Non implemented database type: <xdb.\type>";
      }
      
    }
    
    int dtPos = 0;
    for (xdt:"dataTypes"(list[node] xelts) <- kids) {
       dtPath = "//@dataTypes.<dtPos>";
           
       switch (get(xdt, "type")) {
         case "typhonml:PrimitiveDataType": {
           ensurePrimitive(dtPath);
           pr = typeMap[dtPath].primitiveDataType;
           pr.name = get(xdt, "name");
           dts += [DataType(pr)];
         }
         
         case "typhonml:Entity": {
           attrs = [];
           for (xattr:"attributes"(_) <- xelts) {
             attr = realm.new(#Attribute, Attribute(get(xattr, "name")));
             aPath = get(xattr, "type");
             ensurePrimitive(aPath);
             attr.\type = referTo(#DataType, typeMap[aPath]);
             attrs += [attr]; 
           }  
         
           rels = [];
           relPos = 0;
           for (xrel:"relations"(_) <- xelts) {
             relPath = "<dtPath>/@relations.<relPos>";
             ensureRel(relPath);
             myrel = relMap[relPath];
             myrel.name = get(xrel, "name");
             myrel.cardinality = make(#Cardinality, get(xrel, "cardinality"), []);
             
             ePath = get(xrel, "type");
             ensureEntity(ePath);
             myrel.\type = referTo(#Entity, typeMap[ePath].entity);
             
             if ("opposite" in getKeywordParameters(xrel)) {
               oppPath = get(xrel, "opposite");
               ensureRel(oppPath);
               myrel.opposite = referTo(#Relation, relMap[oppPath]);
             }
             
             if ("isContainment" in getKeywordParameters(xrel)) {
               myrel.isContainment = get(xrel, "isContainment") == "true";
             } 
             
             
             rels += [myrel];
             relPos += 1;
           }

           ensureEntity(dtPath);
            
           entity = typeMap[dtPath].entity;
           entity.name = get(xdt, "name");
           entity.attributes = attrs;
           entity.fretextAttributes = []; // todo;
           entity.relations = rels;
           dt = DataType(entity);              
           dts += [dt];
         }
       }
       
       dtPos += 1;
    }
    
    return  realm.new(#Model, Model(dbs, dts, [] /* todo */));
  }
  else {
    throw "Invalid XMI node <n>";
  }
  
  
  
}