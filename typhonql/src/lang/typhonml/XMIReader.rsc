module lang::typhonml::XMIReader

import lang::xml::IO;
import lang::typhonml::TyphonML;
import lang::ecore::Refs;

import lang::typhonml::Util;

import IO;
import Node;
import Type;
import String;

import util::ValueUI;

list[str] typhonMLexamples() = [
//"it.univaq.disim.typhonml.parent/bundles/it.univaq.disim.typhonml/model/TyphonECommerceExample.xmi",
//"it.univaq.disim.typhonml.parent/bundles/it.univaq.disim.typhonml.model_analysis/resources/mydb.xmi",
//"it.univaq.disim.typhonml.parent/bundles/it.univaq.disim.typhonml.repository/repository/test/demo.xmi",
//"it.univaq.disim.typhonml.parent/bundles/it.univaq.disim.typhonml.repository/repository/test/generated_demo.xmi",
//"it.univaq.disim.typhonml.parent/bundles/it.univaq.disim.typhonml.repository/repository/weather_warning/dl/weather_warning_ML.xmi"
];

list[loc] copiedModels() = [
|project://typhonql/src/lang/typhonml/newexample.xmi|
//|project://typhonql/src/lang/typhonml/alphabank.xmi|,
//|project://typhonql/src/lang/typhonml/complexModelWithChangeOperators.xmi|,
//|project://typhonql/src/lang/typhonml/customdatatypes.xmi|,
//|project://typhonql/src/lang/typhonml/demodb.xmi|,
//|project://typhonql/src/lang/typhonml/mydb4.xmi|,
//|project://typhonql/src/lang/typhonml/user-review-product-bio.xmi|
];
 


void smokeTest(str root = "/Users/tvdstorm/CWI/typhonml") {
  for (str ex <- typhonMLexamples()) {
    println("TESTING: <ex>");
    str xmi = readFile(|file://<root>/<ex>|);
    Model m = xmiString2Model(xmi);
    //iprintln(m);
    iprintln(model2schema(m));
  }
  
  for (loc ex <- copiedModels()) {
    println("TESTING (copied model): <ex>");
    str xmi = readFile(ex);
    Model m = xmiString2Model(xmi);
    iprintln(m);
    iprintln(model2schema(m));
  }
}





void smokeTest2() {
  str xmi = readFile(|project://typhonql/src/lang/typhonml/customdatatypes.xmi|);
  Model m = xmiString2Model(xmi);
  Schema s = model2schema(m);
  //iprintln(m);
  iprintln(s);
}

Model loadTyphonML(loc l) = xmiString2Model(readFile(l));

Model xmiString2Model(str s) = xmiNode2Model(readXML(s));

Schema loadSchemaFromXMI(str s) = model2schema(m)
	when Model m := xmiString2Model(s);

@doc{
Convert a node representation of the XMI serialization of a TyphonML model
to a `lang::typhoml::TyphonML::Model` value.

Omissions for now:
 - evolution operators
 - database types other than document and relation
}
Model xmiNode2Model(node n) {  
  Realm realm = newRealm();
  
  list[Entity] es = [];
  list[Database] dbs = [];
  list[CustomDataType] cdts = [];
  list[ChangeOperator] chos = [];
  
  str get(node n, str name) = x 
    when str x := getKeywordParameters(n)[name];
    
  bool has(node n, str name) = name in (getKeywordParameters(n));
  
  map[str, Entity] entityMap = ();
  map[str, CustomDataType] customMap = ();
  map[str, Relation] relMap = ();
  
  
  Entity ensureEntity(str path) {
    if (path notin entityMap) {
      entityMap[path] = realm.new(#Entity, Entity("", [], [], [], []));
    }
    return entityMap[path];
  }

  PrimitiveDataType makePrimitive(str name, list[value] params) {
    switch (<name, params>) {
      case <"IntType", []> : return PrimitiveDataType(realm.new(#IntType, IntType()));
      case <"BigintType", []> : return PrimitiveDataType(realm.new(#BigintType, BigintType()));
      case <"StringType", [int n]> : return PrimitiveDataType(realm.new(#StringType, StringType(maxSize=n)));
      case <"BlobType", []> : return PrimitiveDataType(realm.new(#BlobType, BlobType()));
      case <"BoolType", []> : return PrimitiveDataType(realm.new(#BoolType, BoolType()));
      case <"TextType", []> : return PrimitiveDataType(realm.new(#TextType, TextType()));
      case <"DateType", []> : return PrimitiveDataType(realm.new(#DateType, DateType()));
      case <"PointType", []> : return PrimitiveDataType(realm.new(#PointType, PointType()));
      case <"DatetimeType", []> : return PrimitiveDataType(realm.new(#DatetimeType, DatetimeType()));
      case <"PolygonType", []> : return PrimitiveDataType(realm.new(#PolygonType, PolygonType()));
      case <"FloatType", []> : return PrimitiveDataType(realm.new(#FloatType, FloatType()));
      case <"FreetextType", [list[NlpTask] tasks]> : return PrimitiveDataType(realm.new(#FreetextType, FreetextType(tasks)));
      default: throw "Unsupported primitive: <name>(<params>)";
    }
  }  
  
  CustomDataType ensureCustom(str path) {
    if (path notin customMap) {
      customMap[path] = realm.new(#CustomDataType, CustomDataType("", []));
    }
    return customMap[path];
  }
  
  
  
  Relation ensureRel(str path) {
    if (path notin relMap) {
      relMap[path] = realm.new(#Relation, Relation("", zero_one()));
    }
    return relMap[path];
  }
  
  if ("Model"(list[node] kids) := n) {

    for (xdb:"databases"(list[node] xelts) <- kids) {
      switch (get(xdb, "type")) {
        case "typhonml:RelationalDB": {
          tbls = [];
          for (xtbl:"tables"(_) <- xelts) {
            tbl = realm.new(#Table, Table(get(xtbl, "name")));
            ep = get(xtbl, "entity");
            tbl.entity = referTo(#Entity, ensureEntity(ep));
            tbls += [tbl];
          }
          
          dbs += [ realm.new(#Database, Database(RelationalDB(get(xdb, "name"), tbls)))];
        }
        
        case "typhonml:DocumentDB": {
          colls = [];
          for (xcoll:"collections"(_) <- xelts) {
            coll = realm.new(#Collection, Collection(get(xcoll, "name")));
            ep = get(xcoll, "entity");
            coll.entity = referTo(#Entity, ensureEntity(ep));
            colls += [coll];
          }
          
          dbs += [ realm.new(#Database, Database(DocumentDB(get(xdb, "name"), colls))) ];
        }
        
        default:
          throw "Non implemented database type: <xdb.\type>";
      }
      
    }
    
    for (xcho:"changeOperators"(list[node] xelts) <- kids) {
      switch (get(xcho, "type")) {
        case "typhonml:RemoveEntity": {
        	e = get(xcho, "entityToRemove");
        	toRemove = referTo(#Entity, ensureEntity(e).entity);
        	re = realm.new(#RemoveEntity, RemoveEntity(toRemove));
          	chos += [ ChangeOperator(re)];
        } // ChangeOperator(RemoveEntity \removeEntity, lang::ecore::Refs::Ref[Entity] \entityToRemove = \removeEntity.\entityToRemove, lang::ecore::Refs::Id uid = \removeEntity.uid, bool _inject = true) ];
        
         case "typhonml:RenameEntity": {
        	e = get(xcho, "entityToRename");
        	newName = get(xcho, "newEntityName");
        	toRename = referTo(#Entity, ensureEntity(e).entity);
        	re = realm.new(#RenameEntity, RenameEntity(\entityToRename = toRename, \newEntityName = newName));
          	chos += [ ChangeOperator(re)];
        }
        default: {
          println("WARNING: Non implemented change operator: <get(xcho, "type")>");
        }
      }
      
    }
    
    int entPos = 0;
    
    for (xen:"entities"(list[node] xelts) <- kids) {
      entPath = "//@entities.<entPos>";
      
      list[EntityAttribute] attrs = [];
      
      for (xattr:"attributes"(list[node] attrElts) <- xelts) {
         DataType dt = DataType(PrimitiveDataType(realm.new(#IntType, IntType()))); // dummy;
         // todo: custom data types!
         
         if (xtype:"type"(list[node] typeElts) <- attrElts) {
           switch (get(xtype, "type")) {
             case "typhonml:FreetextType" : {
               list[NlpTask] tasks = [ realm.new(#NlpTask, NlpTask(get(x, "workflowName"), make(#NlpTaskType, get(x, "type"), []))) 
                                          | x:"tasks"(_) <- typeElts ];
               dt = DataType(makePrimitive("FreetextType", [tasks]));
             }
             case "typhonml:StringType" : {
               dt = DataType(makePrimitive("StringType", [has(xtype, "maxSize") ? toInt(get(xtype, "maxSize")) : 0])); 
             }
             case /^typhonml:<rest:.*>$/: {
               dt = DataType(makePrimitive(rest, []));
             } 
             default: throw "Unknown attribute type: <xtype>";
           }
         }
         
         EntityAttribute attr = EntityAttribute(realm.new(#Attribute, Attribute(get(xattr, "name"), dt)));
         attrs += [attr]; 
      }  
       
      list[Relation] rels = [];
      relPos = 0;
      for (xrel:"relations"(_) <- xelts) {
         relPath = "<entPath>/@relations.<relPos>";
         myrel = ensureRel(relPath);
         myrel.name = get(xrel, "name");
         if (has(xrel, "cardinality")) {
         	myrel.cardinality = make(#Cardinality, get(xrel, "cardinality"), []);
         }
         else {
         	myrel.cardinality =  make(#Cardinality, "zero_one", []);
         }
         
         ePath = get(xrel, "type");
         myrel.\type = referTo(#Entity, ensureEntity(ePath));
         
         if ("opposite" in getKeywordParameters(xrel)) {
           oppPath = get(xrel, "opposite");
           myrel.opposite = referTo(#Relation, ensureRel(oppPath));
         }
         
         if ("isContainment" in getKeywordParameters(xrel)) {
           myrel.isContainment = get(xrel, "isContainment") == "true";
         } 
         
         
         rels += [myrel];
         relPos += 1;
      }
       

      entity = ensureEntity(entPath);
      entity.name = get(xen, "name");
      entity.attributes = attrs;
      entity.relations = rels;
      es += [entity];
      
      entPos += 1;
    }
    
    int dtPos = 0;
    for (xdt:"customDataTypes"(list[node] xelts) <- kids) {
       dtPath = "//@customDataTypes.<dtPos>";
       //println("Data type path: <dtPath>");
       //println(xdt);
           
       list[CustomDataTypeItem] elements = [];
       for (xattr:"elements"(_) <- xelts) {
         el = realm.new(#DataTypeItem, DataTypeItem(get(xattr, "name"), DataTypeImplementationPackage()));
         aPath = get(xattr, "type");
         el.\type = referTo(#DataType, ensurePrimitive(aPath));
         elements += [el]; 
       }
       custom = ensureCustom(dtPath);
       custom.name = get(xdt, "name");
       custom.elements = elements;   
       cdts += [custom];

       dtPos += 1;
    }
    
    return  realm.new(#Model, Model(es, dbs, cdts, chos));
  }
  else {
    throw "Invalid Typhon ML XMI node <n>";
  }
  
  
  
}