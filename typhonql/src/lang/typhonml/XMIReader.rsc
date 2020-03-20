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

void smokeTest() {
  str xmi = readFile(|project://typhonql/src/test/splitVerticalEntityChangeOperator.xmi|);
  Model m = xmiString2Model(xmi);
  iprintln(m);
  iprintln(model2schema(m));
}


void smokeTest2() {
  str xmi = readFile(|project://typhonql/src/lang/typhonml/removeAttributeChangeOperator.xmi|);
  Model m = xmiString2Model(xmi);
  Schema s = model2schema(m);
  //iprintln(m);
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
  
  list[Database] dbs = [];
  list[DataType] dts = [];
  list[ChangeOperator] chos = [];
  
  str get(node n, str name) = x 
    when str x := getKeywordParameters(n)[name];
    
  bool has(node n, str name) = name in (getKeywordParameters(n));
  
  map[str, DataType] typeMap = ();
  map[str, Relation] relMap = ();
  map[str, Database] dbMap = ();
  map[str, Attribute] attrMap = ();
  
  DataType ensureEntity(str path) {
    if (path notin typeMap) {
      typeMap[path] = DataType(realm.new(#Entity, Entity("", [], [], [])));
    }
    return typeMap[path];
  }
  
  DataType ensurePrimitive(str path) {
    if (path notin typeMap) {
      typeMap[path] = DataType(realm.new(#PrimitiveDataType, PrimitiveDataType("")));
    }
    else {
      typeMap[path] = DataType(realm.new(#PrimitiveDataType, PrimitiveDataType(""), id = typeMap[path].uid));
    }
    return typeMap[path];
  }
  
  DataType ensureCustom(str path) {
    if (path notin typeMap) {
      typeMap[path] = DataType(realm.new(#CustomDataType, CustomDataType("", [])));
    }
    else {
      typeMap[path] = DataType(realm.new(#CustomDataType, CustomDataType("", []), id = typeMap[path].uid));
    }
    
    return typeMap[path];
  }
  
  
  Relation ensureRel(str path) {
    if (path notin relMap) {
      relMap[path] = realm.new(#Relation, Relation("", zero_one()));
    }
    return relMap[path];
  }
  
  Attribute ensureAttr(str path) {
    if (path notin attrMap) {
      attrMap[path] = realm.new(#Attribute, Attribute(""));
    }
    return attrMap[path];
  }
  
  if ("typhonml:Model"(list[node] kids) := n) {

	int dbPos = 0;
	
    for (xdb:"databases"(list[node] xelts) <- kids) {
      dbPath = "//@databases.<dbPos>";
    	
      switch (get(xdb, "xsi:type")) {
        case "typhonml:RelationalDB": {
          tbls = [];
          for (xtbl:"tables"(_) <- xelts) {
            tbl = realm.new(#Table, Table(get(xtbl, "name")));
            ep = get(xtbl, "entity");
            tbl.entity = referTo(#Entity, ensureEntity(ep).entity);
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
            coll.entity = referTo(#Entity, ensureEntity(ep).entity);
            colls += [coll];
          }
          
          db = realm.new(#Database, Database(DocumentDB(get(xdb, "name"), colls)));
          
          dbMap[dbPath] = db;
          dbs += [db];
        }
        
        default:
          throw "Non implemented database type: <xdb.\type>";
      }
      dbPos += 1;
    }
    
    
    int dtPos = 0;
    for (xdt:"dataTypes"(list[node] xelts) <- kids) {
       dtPath = "//@dataTypes.<dtPos>";
           
       switch (get(xdt, "xsi:type")) {
       	 case "typhonml:PrimitiveDataType": {
           pr = ensurePrimitive(dtPath).primitiveDataType;
           pr.name = get(xdt, "name");
           dts += [DataType(pr)];
         }
         
         case "typhonml:CustomDataType": {
           list[DataTypeItem] elements = [];
           for (xattr:"elements"(_) <- xelts) {
             el = realm.new(#DataTypeItem, DataTypeItem(get(xattr, "name"), DataTypeImplementationPackage()));
             aPath = get(xattr, "type");
             el.\type = referTo(#DataType, ensurePrimitive(aPath));
             elements += [el]; 
           }
           custom = ensureCustom(dtPath).customDataType;
           custom.name = get(xdt, "name");
           custom.elements = elements;   
           dt = DataType(custom);  
           dts+= [dt];
         }
         
         case "typhonml:Entity": {
           attrs = [];
           attrPos = 0;
           for (xattr:"attributes"(_) <- xelts) {
           	 attrPath = "<dtPath>/@attributes.<attrPos>";
           	 
           	 attr = ensureAttr(attrPath);
             attr.name = get(xattr, "name");
             aPath = get(xattr, "type");
             attr.\type = referTo(#DataType, ensurePrimitive(aPath));
             attr.ownerEntity = referTo(#Entity, ensureEntity(dtPath).entity);
             attrs += [attr];
             attrPos += 1; 
           }  
         
           rels = [];
           relPos = 0;
           for (xrel:"relations"(_) <- xelts) {
             relPath = "<dtPath>/@relations.<relPos>";
             myrel = ensureRel(relPath);
             myrel.ownerEntity = referTo(#Entity, ensureEntity(dtPath).entity);
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

           entity = ensureEntity(dtPath).entity;
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
    
    int chOpPos = 0;
    for (xcho:"changeOperators"(list[node] xelts) <- kids) {
      dtPath = "//@changeOperators.<chOpPos>";
      
      switch (get(xcho, "xsi:type")) {
      	
      	case "typhonml:AddEntity":{
      		
      		attrs = [];
           	for (xattr:"attributes"(_) <- xcho) {
             	attr = realm.new(#Attribute, Attribute(get(xattr, "name")));
             	aPath = get(xattr, "type");
             	attr.\type = referTo(#DataType, ensurePrimitive(aPath));
             	attrs += [attr]; 
           	}  
           	
           	
           	rels = [];
           	relPos = 0;
          	for (xrel:"relations"(_) <- xcho) {
             	relPath = "<dtPath>/@relations.<relPos>";
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
      		re = realm.new(#AddEntity, AddEntity(name, attrs, [], rels));
      		chos += [ ChangeOperator(re)];
           	
           	entity = ensureEntity(dtPath).entity;
           	entity.name = name;
           	entity.attributes = attrs;
           	entity.fretextAttributes = []; // todo;
           	entity.relations = rels;
           	dt = DataType(entity);   
           	
      		dts += [dt];
      	}
      	
      	case "typhonml:AddRelation":{
      	
      		e = get(xcho, "ownerEntity");
      		entity = referTo(#Entity, ensureEntity(e).entity);
      		
      		cardinality = make(#Cardinality, "zero_one", []);
      		if (has(xcho, "cardinality"))
             	cardinality = make(#Cardinality, get(xcho, "cardinality"), []);

      		
      		containement = get(xcho, "isContainment") == "true";
      		name = get(xcho, "name");
      		
      		t = get(xcho, "type");
      		ty = referTo(#DataType, ensurePrimitive(t));
      		
      		re = realm.new(#AddRelation, AddRelation(name, cardinality,entity, containement,ty));
      		chos += [ ChangeOperator(re)];
      	}
      	
      	case "typhonml:AddAttribute":{
      		t = get(xcho, "type");
      		ty = referTo(#DataType, ensurePrimitive(t));
      		
      		e = get(xcho, "ownerEntity");
      		entity = referTo(#Entity, ensureEntity(e).entity);
      		
      		name = get(xcho, "name");
      		
      		re = realm.new(#AddAttribute, AddAttribute(name,entity,ty));
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
      		firstEntityToMerge = referTo(#Entity, ensureEntity(e1).entity);
      		
      		e2 = get(xcho, "secondEntityToMerge");
      		secondEntityToMerge = referTo(#Entity, ensureEntity(e2).entity);
      		
      		newEntityName = get(xcho, "newEntityName");
      		
      		re = realm.new(#MergeEntity, MergeEntity(firstEntityToMerge, secondEntityToMerge, newEntityName));
      		chos += [ChangeOperator(re)];
      	}
      	
      	case "typhonml:MigrateEntity": {
      		e1 = get(xcho, "entity");
      		entity = referTo(#Entity, ensureEntity(e1).entity);
      		
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
        	toRemove = referTo(#Entity, ensureEntity(e).entity);
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
        	
        	re = realm.new(#RenameAttribute, RenameAttribute(ref_attr, name));
          	chos += [ ChangeOperator(re)];
        }
   
        case "typhonml:RenameEntity": {
        	e = get(xcho, "entityToRename");
        	
        	newName = get(xcho, "newEntityName");
        	toRename = referTo(#Entity, ensureEntity(e).entity);
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
        	toSplit = referTo(#Entity, ensureEntity(e).entity);
        	
        	a = get(xcho, "attributeList");
        	l_a = split(" ", a);
        	list_attr = [];
        	
        	for(str to_do <- l_a){
        		list_attr += [referTo(#Attribute, ensureAttr(to_do))];
        	};	
        	
        	re = realm.new(#SplitEntityVertical, SplitEntityVertical(name, toSplit, list_attr));
          	chos += [ ChangeOperator(re)];
        }
        
        case "typhonml:SplitEntityHorizontal":{
        	name = get(xcho, "entity2name");
        	
        	e = get(xcho, "entity1");
        	toSplit = referTo(#Entity, ensureEntity(e).entity);
        	
        	a = get(xcho, "attribute");
        	ref_attr = referTo(#Attribute, ensureAttr(a));
        	
        	expr = get(xcho, "expression");
        	
        	re = realm.new(#SplitEntityHorizontal, SplitEntityHorizontal(name, toSplit, ref_attr, expr));
          	chos += [ ChangeOperator(re)];
        }
       	
        
        default:
          throw "Non implemented change operator: <get(xcho, "xsi:type")>";
      }
      
      chOpPos += 1;
      
    }
    return  realm.new(#Model, Model(dbs, dts, chos));
  }
  else {
    throw "Invalid Typhon ML XMI node <n>";
  }
  
  
  
}