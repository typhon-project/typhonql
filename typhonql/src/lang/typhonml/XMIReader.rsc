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
|project://typhonql/src/lang/typhonql/test/resources/user-review-product/user-review-product.xmi|
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
  str xmi = readFile(|project://typhonql/src/test/RemoveAttributes.xmi|);
  Model m = xmiString2Model(xmi);
  Schema s = model2schema(m);
  iprintln(m);
  iprintln(s);
}

void smokeTest3() {
  str xmi = readFile(|project://typhonql/src/lang/typhonql/test/resources/user-review-product/user-review-product.xmi|);
  Model m = xmiString2Model(xmi);
  iprintln(m);
  Schema s = model2schema(m);
  iprintln(s);
}


Model loadTyphonML(loc l) = xmiString2Model(readFile(l));

Model xmiString2Model(str s) = xmiNode2Model(readXML(s, fullyQualify=true));

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
  map[str, Database] dbMap = ();
  map[str, Attribute] attrMap = ();
  
  
  Entity ensureEntity(str path) {
    if (path notin entityMap) {
      entityMap[path] = realm.new(#Entity, Entity("", [], [], [], []));
    }
    return entityMap[path];
  }

  DataType makePrimitive(str name, list[value] params) {
    switch (<name, params>) {
      case <"IntType", []> : return DataType(realm.new(#IntType, IntType()));
      case <"BigintType", []> : return DataType(realm.new(#BigintType, BigintType()));
      case <"StringType", [int n]> : return DataType(realm.new(#StringType, StringType(maxSize=n)));
      case <"BlobType", []> : return DataType(realm.new(#BlobType, BlobType()));
      case <"BoolType", []> : return DataType(realm.new(#BoolType, BoolType()));
      case <"TextType", []> : return DataType(realm.new(#TextType, TextType()));
      case <"DateType", []> : return DataType(realm.new(#DateType, DateType()));
      case <"PointType", []> : return DataType(realm.new(#PointType, PointType()));
      case <"DatetimeType", []> : return DataType(realm.new(#DatetimeType, DatetimeType()));
      case <"PolygonType", []> : return DataType(realm.new(#PolygonType, PolygonType()));
      case <"FloatType", []> : return DataType(realm.new(#FloatType, FloatType()));
      case <"FreetextType", [list[NlpTask] tasks]> : return DataType(realm.new(#FreetextType, FreetextType(tasks)));
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
  
  Attribute ensureAttr(str path) {
    if (path notin attrMap) {
      DataType dt = DataType(realm.new(#IntType, IntType())); // dummy;
      attrMap[path] = realm.new(#Attribute, Attribute("", dt));
    }
    return attrMap[path];
  }
  
  if ("typhonml-Model"(list[node] kids) := n) {
	int dbPos = 0;
    for (xdb:"databases"(list[node] xelts) <- kids) {
    
      dbPath = "//@databases.<dbPos>";
      
      switch (get(xdb, "xsi-type")) {
        case "typhonml:RelationalDB": {
          tbls = [];
          for (xtbl:"tables"(_) <- xelts) {
            tbl = realm.new(#Table, Table(get(xtbl, "name")));
            ep = get(xtbl, "entity");
            tbl.entity = referTo(#Entity, ensureEntity(ep));
            tbls += [tbl];
          }
          db = realm.new(#Database, Database(RelationalDB(get(xdb, "name"), tbls)));
          
          dbMap[dbPath] = db;
          dbs += [db];
        }
        
        case "typhonml:DocumentDB": {
          colls = [];
          for (xcoll:"collections"(_) <- xelts) {
            coll = realm.new(#Collection, Collection(get(xcoll, "name")));
            ep = get(xcoll, "entity");
            coll.entity = referTo(#Entity, ensureEntity(ep));
            colls += [coll];
          }
          
          db = realm.new(#Database, Database(DocumentDB(get(xdb, "name"), colls)));
          dbMap[dbPath] = db;
          dbs += [db];
        }
        
        case "typhonml:KeyValueDB": {
          list[KeyValueElement] elts = [];
          for (xelt:"elements"(_) <- xelts) {
            elt = realm.new(#KeyValueElement, KeyValueElement(get(xelt, "name"), []));
            elt.key = get(xelt, "key");
            valsStr = get(xelt, "values");
            elt.values =  [ referTo(#Attribute, ensureAttr(path)) | str path <- split(" ", valsStr) ];
            elts += [elt];
          }
          db = realm.new(#Database, Database(KeyValueDB(get(xdb, "name"), elts)));
          dbMap[dbPath] = db;
          dbs += [db];
        }
        
        default:
          throw "Non implemented database type: <get(xdb, "xsi-type")>";
      }
      dbPos += 1;
      
    }
    
    int entPos = 0;
    
    for (xen:"entities"(list[node] xelts) <- kids) {
      entPath = "//@entities.<entPos>";
      
      list[EntityAttributeKind] attrs = [];
      attrPos = 0;
      
      for (xattr:"attributes"(list[node] attrElts) <- xelts) {
         attrPath = "<entPath>/@attributes.<attrPos>";
         if (get(xattr, "xsi-type") == "typhonml:Attribute", xtype:"type"(list[node] typeElts) <- attrElts) {
           DataType dt = DataType(realm.new(#IntType, IntType())); // dummy;
         
           switch (get(xtype, "xsi-type")) {
             case "typhonml:FreetextType" : {
               list[NlpTask] tasks = [ realm.new(#NlpTask, NlpTask(get(x, "workflowName"), make(#NlpTaskType, get(x, "type"), []))) 
                                          | x:"tasks"(_) <- typeElts ];
               dt = makePrimitive("FreetextType", [tasks]);
             }
             case "typhonml:StringType" : {
               dt = makePrimitive("StringType", [has(xtype, "maxSize") ? toInt(get(xtype, "maxSize")) : 0]); 
             }
             case /^typhonml:<rest:.*>$/: {
               dt = makePrimitive(rest, []);
             } 
             default: throw "Unknown attribute type: <xtype>";
           }

           Attribute attr = ensureAttr(attrPath);
           attr.name = get(xattr, "name");
           attr.\type = dt;
           attrs += [EntityAttributeKind(attr)];
           attrPos += 1;
         }
         else {
          // if (get(xattr, "type") == "typhonml:CustomAttribute") {
           // "type" is unfortunately overloaded and cannot be reused here
           // the first one is xsi:type (which should be "typhonml:CustomAttribute")
           // the other one is just type; we thus assume that type
           // refers to the typhonML type, not the Ecore type. 
           attr = EntityAttributeKind(realm.new(#CustomAttribute, 
              CustomAttribute(get(xattr, "name"), referTo(#CustomDataType, ensureCustom(get(xattr, "type"))))));
           attrs += [attr];
           // TODO: we need to put it in the map as well, 
           // so that evolution operators can refer to it;
           // however, this means that the map should indeed
           // be from path to EntityAttributeKind, which is
           // for now a bit involved, since no ChangeOperator
           // every refers to a custom data type attribute AFAIK
           //attrMap[attrPath] = attr;
           attrPos += 1;
         }
         
          
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
           
       list[SuperDataType] elements = [];
       
       for (xattr:"elements"([node xtype]) <- xelts) {
         switch (get(xattr, "xsi-type")) {
           case "typhonml:SimpleDataType": {
             dt = makePrimitive("IntType", []); // dummy
             switch (get(xtype, "xsi-type")) {
               case "typhonml:FreetextType" : {
                 list[NlpTask] tasks = [ realm.new(#NlpTask, NlpTask(get(x, "workflowName"), make(#NlpTaskType, get(x, "type"), []))) 
                                          | x:"tasks"(_) <- typeElts ];
                 dt = makePrimitive("FreetextType", [tasks]);
               }
               
               case "typhonml:StringType" : {
                 dt = makePrimitive("StringType", [has(xtype, "maxSize") ? toInt(get(xtype, "maxSize")) : 0]); 
               }
             
               case /^typhonml:<rest:.*>$/: {
                 dt = makePrimitive(rest, []);
               } 
               default: throw "Unknown attribute type: <xtype>";
             }
             el = SuperDataType(realm.new(#SimpleDataType, SimpleDataType(get(xattr, "name"), dt)));
             elements += [el];
           }
           case "typhonml:ComplexDataType": {
             el = ComplexDataType(get(xattr, "name"), ensureCustom(dtPath));
             elements += [el];
           }
         }
       }
       custom = ensureCustom(dtPath);
       custom.name = get(xdt, "name");
       custom.elements = elements;   
       cdts += [custom];

       dtPos += 1;
    }
    
    for (xcho:"changeOperators"(list[node] xelts) <- kids) {
      switch (get(xcho, "xsi-type")) {
      
        case "typhonml:AddEntity":{
        	entPath = "//@entities.<entPos>";
      		attrs = [];
            attrPos = 0;
            for (xattr:"attributes"(_) <- xcho) {
           	 	attrPath = "<dtPath>/@attributes.<attrPos>";
           	 	println(attrPath)
           	 	attr = ensureAttr(attrPath);
             	attr.name = get(xattr, "name");
             	aPath = get(xattr, "type");
             	attr.\type = referTo(#DataType, ensurePrimitive(aPath));
             	// attr.ownerEntity = referTo(#Entity, ensureEntity(dtPath).entity);
             	attrs += [attr];
             	attrPos += 1; 
           	}  
      			
           	for (xattr:"attributes"(_) <- xcho) {
             	attr = realm.new(#Attribute, Attribute(get(xattr, "name")));
             	aPath = get(xattr, "type");
             	attr.\type = referTo(#DataType, ensurePrimitive(aPath));
             	attrs += [attr]; 
           	}  
           	
           	
           	rels = [];
           	relPos = 0;
          	for (xrel:"relations"(_) <- xcho) {
             	relPath = "<entPath>/@relations.<relPos>";
             	myrel = ensureRel(relPath);
             	myrel.name = get(xrel, "name");
             	if (has(xrel, "cardinality"))
             		myrel.cardinality = make(#Cardinality, get(xrel, "cardinality"), []);
             	else
             		myrel.cardinality =  make(#Cardinality, "zero_one", []);
             
             	ePath = get(xrel, "type");
             	myrel.\type = referTo(#Entity, ensureEntity(ePath).entity);
             
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
           	
           	name = get(xcho, "name");
      		re = realm.new(#AddEntity, AddEntity(name, attrs, rels,[], []));
      		chos += [ ChangeOperator(re)];
           	
           	entity = ensureEntity(entPath);
           	entity.name = name;
           	entity.attributes = attrs;
           	entity.relations = rels;
           	
      		es += [entity];
      		entPos = entPos + 1;
      	}
      	
      	case "typhonml:AddRelation":{
      		e = get(xcho, "ownerEntity");
      		entity = referTo(#Entity, ensureEntity(e));
      		
      		cardinality = make(#Cardinality, "zero_one", []);
      		if (has(xcho, "cardinality"))
             	cardinality = make(#Cardinality, get(xcho, "cardinality"), []);

      		name = get(xcho, "name");
      		
      		t = get(xcho, "type");
      		ty = referTo(#Entity, ensureEntity(t));
      		
      		re = realm.new(#AddRelation, AddRelation(name, cardinality, entity));
      		re.\type = ty;	
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:AddAttribute":{
      		t = get(xcho, "type");
      		ty = referTo(#DataType, ensurePrimitive(t));
      		
      		e = get(xcho, "ownerEntity");
      		entity = referTo(#Entity, ensureEntity(e).entity);
      		
      		name = get(xcho, "name");
      		
      		re = realm.new(#AddAttribute, AddAttribute(name,ty, entity, ty));
      		chos += [ ChangeOperator(re)];
      	}
      	
      	case "typhonml:ChangeRelationCardinality":{
      		relPath = get(xcho, "relation");
      		
      		relref = referTo(#Relation ,ensureRel(relPath));
      		cardinality = make(#Cardinality, get(xcho, "newCardinality"), []);
      		
      		re = realm.new(#ChangeRelationCardinality, ChangeRelationCardinality(relref, cardinality));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:ChangeRelationContainement": {
      		relPath = get(xcho, "relation");
      		
      		relref = referTo(#Relation ,ensureRel(relPath));
      		containement = get(xcho, "newContainment") == "true";
      		
      		re = realm.new(#ChangeRelationContainement, ChangeRelationContainement(relref, containement));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:ChangeAttributeType": {
      		attr_path = get(xcho, "attributeToChange");
      		type_path = get(xcho, "newType");
      		
      		ty = referTo(#DataType, ensurePrimitive(type_path));
      		attr = referTo(#Attribute, ensureAttr(attr_path));
      		
      		re = realm.new(#ChangeAttributeType, ChangeAttributeType(attr, ty));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:DisableRelationContainment": {
      		relPath = get(xcho, "relation");
      		relref = referTo(#Relation ,ensureRel(relPath));
      		
      		re = realm.new(#DisableRelationContainment, DisableRelationContainment(relref));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:DisableBidirectionalRelation": {
      		relPath = get(xcho, "relation");
      		relref = referTo(#Relation ,ensureRel(relPath));
      		
      		re = realm.new(#DisableBidirectionalRelation, DisableBidirectionalRelation(relref));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:EnableRelationContainment": {
      		relPath = get(xcho, "relation");
      		relref = referTo(#Relation ,ensureRel(relPath));
      		
      		re = realm.new(#EnableRelationContainment, EnableRelationContainment(relref));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:EnableBidirectionalRelation": {
      		relPath = get(xcho, "relation");
      		relref = referTo(#Relation ,ensureRel(relPath));
      		
      		re = realm.new(#EnableBidirectionalRelation, EnableBidirectionalRelation(relref));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:MergeEntity" : {
      	
      		e1 = get(xcho, "firstEntityToMerge");
      		firstEntityToMerge = referTo(#Entity, ensureEntity(e1));
      		
      		e2 = get(xcho, "secondEntityToMerge");
      		secondEntityToMerge = referTo(#Entity, ensureEntity(e2));
      		
      		newEntityName = get(xcho, "newEntityName");
      		
      		re = realm.new(#MergeEntity, MergeEntity(firstEntityToMerge, secondEntityToMerge));
      		re.\newEntityName = newEntityName;
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:MigrateEntity": {
      		e1 = get(xcho, "entity");
      		entity = referTo(#Entity, ensureEntity(e1));
      		
      		db_name = get(xcho, "newDatabase");
      		db = referTo(#Database, dbMap[db_name]);
      		
      		re = realm.new(#MigrateEntity, MigrateEntity(entity, db));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:RemoveAttribute":{
      		attr = get(xcho, "attributeToRemove");
      		ref_attr = referTo(#Attribute, ensureAttr(attr));
      		
      		re = realm.new(#RemoveAttribute, RemoveAttribute(ref_attr));
      		chos += [ChangeOperator(re)];
      	}
      	
        case "typhonml:RemoveEntity": {
        	e = get(xcho, "entityToRemove");
        	toRemove = referTo(#Entity, ensureEntity(e));
        	re = realm.new(#RemoveEntity, RemoveEntity(toRemove));
          	chos += [ ChangeOperator(re)];
        }
        
        case "typhonml:RemoveRelation":{
        	relPath = get(xcho, "relationToRemove");
      		relref = referTo(#Relation ,ensureRel(relPath));
      		
      		re = realm.new(#RemoveRelation, RemoveRelation(relref));
          	chos += [ ChangeOperator(re)];
        }
        
        case "typhonml:RenameAttribute": {
        
        	attr = get(xcho, "attributeToRename");
      		ref_attr = referTo(#Attribute, ensureAttr(attr));
      		
      		name = get(xcho, "newName");
        	
        	re = realm.new(#RenameAttribute, RenameAttribute(ref_attr));
        	re.\newName = name;
          	chos += [ ChangeOperator(re)];
        }
   
        case "typhonml:RenameEntity": {
        	e = get(xcho, "entityToRename");
        	
        	newName = get(xcho, "newEntityName");
        	toRename = referTo(#Entity, ensureEntity(e));
        	re = realm.new(#RenameEntity, RenameEntity(\entityToRename = toRename, \newEntityName = newName));
          	chos += [ ChangeOperator(re)];
        }
        
        case "typhonml:RenameRelation":{
        
        	relPath = get(xcho, "relationToRename");
      		relref = referTo(#Relation ,ensureRel(relPath));
      		
      		name = get(xcho, "newRelationName");
        	
        	re = realm.new(#RenameRelation, RenameRelation(relref, \newRelationName = name));
          	chos += [ ChangeOperator(re)];
        }
        case "typhonml:SplitEntityVertical":{
        	name = get(xcho, "entity2name");
        	
        	e = get(xcho, "entity1");
        	toSplit = referTo(#Entity, ensureEntity(e));
        	
        	a = get(xcho, "attributeList");
        	l_a = split(" ", a);
        	list_attr = [];

        	for(str to_do <- l_a){
        		list_attr += [referTo(#Attribute, ensureAttr(to_do))];
        	};	
        	re = realm.new(#SplitEntityVertical, SplitEntityVertical(toSplit, name, list_attr, []));
          	chos += [ ChangeOperator(re)];
        }
        
        case "typhonml:SplitEntityHorizontal":{
        	name = get(xcho, "entity2name");
        	
        	e = get(xcho, "entity1");
        	toSplit = referTo(#Entity, ensureEntity(e));
        	
        	a = get(xcho, "attribute");
        	ref_attr = referTo(#Attribute, ensureAttr(a));
        	
        	expr = get(xcho, "expression");
        	
        	re = realm.new(#SplitEntityHorizontal, SplitEntityHorizontal(name, toSplit, ref_attr, expr));
          	chos += [ ChangeOperator(re)];
        }
        default: {
          println("WARNING: Non implemented change operator: <get(xcho, "type")>");
        }
      }
      
    }
    
    return  realm.new(#Model, Model(es, dbs, cdts, chos));
  }
  else {
    throw "Invalid Typhon ML XMI node <n>";
  }
  
  
  
}