module lang::typhonml::TyphonML

// Generated code; do not edit.
// Date: $2020-03-30T14:32:08.814+00:00$

import lang::ecore::Refs;
import util::Maybe;
import DateTime;

data NamedElement
  = NamedElement(Column \column
      , str \name = \column.\name
      , str \importedNamespace = \column.\importedNamespace
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes = \column.\attributes
      , lang::ecore::Refs::Ref[Entity] \entity = \column.\entity
      , lang::ecore::Refs::Id uid = \column.uid
      , bool _inject = true)
  | NamedElement(GraphEdgeLabel \graphEdgeLabel
      , str \name = \graphEdgeLabel.\name
      , str \importedNamespace = \graphEdgeLabel.\importedNamespace
      , lang::ecore::Refs::Ref[DataType] \type = \graphEdgeLabel.\type
      , lang::ecore::Refs::Id uid = \graphEdgeLabel.uid
      , bool _inject = true)
  | NamedElement(EntityAttribute \entityAttribute
      , str \name = \entityAttribute.\name
      , str \importedNamespace = \entityAttribute.\importedNamespace
      , lang::ecore::Refs::Id uid = \entityAttribute.uid
      , bool _inject = true)
  | NamedElement(CustomDataType \customDataType
      , str \name = \customDataType.\name
      , str \importedNamespace = \customDataType.\importedNamespace
      , list[CustomDataTypeItem] \elements = \customDataType.\elements
      , lang::ecore::Refs::Id uid = \customDataType.uid
      , bool _inject = true)
  | NamedElement(NFunctionalTag \nFunctionalTag
      , str \name = \nFunctionalTag.\name
      , str \importedNamespace = \nFunctionalTag.\importedNamespace
      , lang::ecore::Refs::Id uid = \nFunctionalTag.uid
      , bool _inject = true)
  | NamedElement(CustomDataTypeItem \customDataTypeItem
      , str \name = \customDataTypeItem.\name
      , str \importedNamespace = \customDataTypeItem.\importedNamespace
      , lang::ecore::Refs::Ref[DataType] \type = \customDataTypeItem.\type
      , CustomDataTypeImplementationPackage \implementation = \customDataTypeItem.\implementation
      , lang::ecore::Refs::Id uid = \customDataTypeItem.uid
      , bool _inject = true)
  | NamedElement(Collection \collection
      , str \name = \collection.\name
      , str \importedNamespace = \collection.\importedNamespace
      , lang::ecore::Refs::Ref[Entity] \entity = \collection.\entity
      , lang::ecore::Refs::Id uid = \collection.uid
      , bool _inject = true)
  | NamedElement(GraphNode \graphNode
      , str \name = \graphNode.\name
      , str \importedNamespace = \graphNode.\importedNamespace
      , list[GraphAttribute] \attributes = \graphNode.\attributes
      , lang::ecore::Refs::Ref[Entity] \entity = \graphNode.\entity
      , lang::ecore::Refs::Id uid = \graphNode.uid
      , bool _inject = true)
  | NamedElement(GraphEdge \graphEdge
      , str \name = \graphEdge.\name
      , str \importedNamespace = \graphEdge.\importedNamespace
      , lang::ecore::Refs::Ref[GraphNode] \from = \graphEdge.\from
      , lang::ecore::Refs::Ref[GraphNode] \to = \graphEdge.\to
      , list[GraphEdgeLabel] \labels = \graphEdge.\labels
      , lang::ecore::Refs::Id uid = \graphEdge.uid
      , bool _inject = true)
  | NamedElement(GraphAttribute \graphAttribute
      , str \name = \graphAttribute.\name
      , str \importedNamespace = \graphAttribute.\importedNamespace
      , lang::ecore::Refs::Ref[Attribute] \value = \graphAttribute.\value
      , lang::ecore::Refs::Id uid = \graphAttribute.uid
      , bool _inject = true)
  | NamedElement(FunctionalTag \functionalTag
      , str \name = \functionalTag.\name
      , str \importedNamespace = \functionalTag.\importedNamespace
      , lang::ecore::Refs::Id uid = \functionalTag.uid
      , bool _inject = true)
  | NamedElement(KeyValueElement \keyValueElement
      , str \name = \keyValueElement.\name
      , str \importedNamespace = \keyValueElement.\importedNamespace
      , str \key = \keyValueElement.\key
      , list[lang::ecore::Refs::Ref[Attribute]] \values = \keyValueElement.\values
      , lang::ecore::Refs::Ref[Entity] \entity = \keyValueElement.\entity
      , lang::ecore::Refs::Id uid = \keyValueElement.uid
      , bool _inject = true)
  | NamedElement(Table \table
      , str \name = \table.\name
      , str \importedNamespace = \table.\importedNamespace
      , IndexSpec \indexSpec = \table.\indexSpec
      , IdSpec \idSpec = \table.\idSpec
      , lang::ecore::Refs::Ref[Database] \db = \table.\db
      , lang::ecore::Refs::Ref[Entity] \entity = \table.\entity
      , lang::ecore::Refs::Id uid = \table.uid
      , bool _inject = true)
  | NamedElement(IndexSpec \indexSpec
      , str \name = \indexSpec.\name
      , str \importedNamespace = \indexSpec.\importedNamespace
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes = \indexSpec.\attributes
      , list[lang::ecore::Refs::Ref[Relation]] \references = \indexSpec.\references
      , lang::ecore::Refs::Ref[Table] \table = \indexSpec.\table
      , lang::ecore::Refs::Id uid = \indexSpec.uid
      , bool _inject = true)
  | NamedElement(Entity \entity
      , str \name = \entity.\name
      , str \importedNamespace = \entity.\importedNamespace
      , list[EntityAttribute] \attributes = \entity.\attributes
      , list[Relation] \relations = \entity.\relations
      , list[FunctionalTag] \functionalTags = \entity.\functionalTags
      , list[NFunctionalTag] \nfunctionalTags = \entity.\nfunctionalTags
      , lang::ecore::Refs::Id uid = \entity.uid
      , bool _inject = true)
  | NamedElement(Database \database
      , str \name = \database.\name
      , str \importedNamespace = \database.\importedNamespace
      , lang::ecore::Refs::Id uid = \database.uid
      , bool _inject = true)
  | NamedElement(Relation \relation
      , str \name = \relation.\name
      , str \importedNamespace = \relation.\importedNamespace
      , lang::ecore::Refs::Ref[Entity] \type = \relation.\type
      , Cardinality \cardinality = \relation.\cardinality
      , lang::ecore::Refs::Ref[Relation] \opposite = \relation.\opposite
      , bool \isContainment = \relation.\isContainment
      , lang::ecore::Refs::Id uid = \relation.uid
      , bool _inject = true)
  ;

data Model
  = Model(list[Entity] \entities
      , list[Database] \databases
      , list[CustomDataType] \customDataTypes
      , list[ChangeOperator] \changeOperators
      , lang::ecore::Refs::Id uid = noId())
  ;

data ChangeOperator
  = ChangeOperator(RenameEntity \renameEntity
      , lang::ecore::Refs::Ref[Entity] \entityToRename = \renameEntity.\entityToRename
      , str \newEntityName = \renameEntity.\newEntityName
      , lang::ecore::Refs::Id uid = \renameEntity.uid
      , bool _inject = true)
  | ChangeOperator(DropCollectionIndex \dropCollectionIndex
      , lang::ecore::Refs::Ref[Collection] \collection = \dropCollectionIndex.\collection
      , lang::ecore::Refs::Id uid = \dropCollectionIndex.uid
      , bool _inject = true)
  | ChangeOperator(AddAttributesToIndex \addAttributesToIndex
      , lang::ecore::Refs::Ref[Table] \table = \addAttributesToIndex.\table
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes = \addAttributesToIndex.\attributes
      , lang::ecore::Refs::Id uid = \addAttributesToIndex.uid
      , bool _inject = true)
  | ChangeOperator(RenameAttribute \renameAttribute
      , lang::ecore::Refs::Ref[Attribute] \attributeToRename = \renameAttribute.\attributeToRename
      , str \newName = \renameAttribute.\newName
      , lang::ecore::Refs::Id uid = \renameAttribute.uid
      , bool _inject = true)
  | ChangeOperator(RemoveAttribute \removeAttribute
      , lang::ecore::Refs::Ref[Attribute] \attributeToRemove = \removeAttribute.\attributeToRemove
      , lang::ecore::Refs::Id uid = \removeAttribute.uid
      , bool _inject = true)
  | ChangeOperator(EnableBidirectionalRelation \enableBidirectionalRelation
      , lang::ecore::Refs::Ref[Relation] \relation = \enableBidirectionalRelation.\relation
      , lang::ecore::Refs::Id uid = \enableBidirectionalRelation.uid
      , bool _inject = true)
  | ChangeOperator(DisableBidirectionalRelation \disableBidirectionalRelation
      , lang::ecore::Refs::Ref[Relation] \relation = \disableBidirectionalRelation.\relation
      , lang::ecore::Refs::Id uid = \disableBidirectionalRelation.uid
      , bool _inject = true)
  | ChangeOperator(DisableRelationContainment \disableRelationContainment
      , lang::ecore::Refs::Ref[Relation] \relation = \disableRelationContainment.\relation
      , lang::ecore::Refs::Id uid = \disableRelationContainment.uid
      , bool _inject = true)
  | ChangeOperator(RenameCollection \renameCollection
      , lang::ecore::Refs::Ref[Collection] \collectionToRename = \renameCollection.\collectionToRename
      , str \newName = \renameCollection.\newName
      , lang::ecore::Refs::Id uid = \renameCollection.uid
      , bool _inject = true)
  | ChangeOperator(MigrateEntity \migrateEntity
      , lang::ecore::Refs::Ref[Entity] \entity = \migrateEntity.\entity
      , lang::ecore::Refs::Ref[Database] \newDatabase = \migrateEntity.\newDatabase
      , lang::ecore::Refs::Id uid = \migrateEntity.uid
      , bool _inject = true)
  | ChangeOperator(RenabeGraphEdgeLabel \renabeGraphEdgeLabel
      , lang::ecore::Refs::Ref[GraphEdge] \edge = \renabeGraphEdgeLabel.\edge
      , str \newName = \renabeGraphEdgeLabel.\newName
      , lang::ecore::Refs::Id uid = \renabeGraphEdgeLabel.uid
      , bool _inject = true)
  | ChangeOperator(AddIndex \addIndex
      , lang::ecore::Refs::Ref[Table] \table = \addIndex.\table
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes = \addIndex.\attributes
      , lang::ecore::Refs::Id uid = \addIndex.uid
      , bool _inject = true)
  | ChangeOperator(SplitEntityHorizontal \splitEntityHorizontal
      , lang::ecore::Refs::Ref[Entity] \entity1 = \splitEntityHorizontal.\entity1
      , str \entity2name = \splitEntityHorizontal.\entity2name
      , lang::ecore::Refs::Ref[Attribute] \attribute = \splitEntityHorizontal.\attribute
      , str \expression = \splitEntityHorizontal.\expression
      , lang::ecore::Refs::Id uid = \splitEntityHorizontal.uid
      , bool _inject = true)
  | ChangeOperator(RenameRelation \renameRelation
      , lang::ecore::Refs::Ref[Relation] \relationToRename = \renameRelation.\relationToRename
      , str \newRelationName = \renameRelation.\newRelationName
      , lang::ecore::Refs::Id uid = \renameRelation.uid
      , bool _inject = true)
  | ChangeOperator(DropIndex \dropIndex
      , lang::ecore::Refs::Ref[Table] \table = \dropIndex.\table
      , lang::ecore::Refs::Id uid = \dropIndex.uid
      , bool _inject = true)
  | ChangeOperator(ChangeRelationContainement \changeRelationContainement
      , lang::ecore::Refs::Ref[Relation] \relation = \changeRelationContainement.\relation
      , bool \newContainment = \changeRelationContainement.\newContainment
      , lang::ecore::Refs::Id uid = \changeRelationContainement.uid
      , bool _inject = true)
  | ChangeOperator(RemoveEntity \removeEntity
      , lang::ecore::Refs::Ref[Entity] \entityToRemove = \removeEntity.\entityToRemove
      , lang::ecore::Refs::Id uid = \removeEntity.uid
      , bool _inject = true)
  | ChangeOperator(AddGraphAttribute \addGraphAttribute
      , str \name = \addGraphAttribute.\name
      , str \importedNamespace = \addGraphAttribute.\importedNamespace
      , lang::ecore::Refs::Ref[Attribute] \value = \addGraphAttribute.\value
      , lang::ecore::Refs::Id uid = \addGraphAttribute.uid
      , bool _inject = true)
  | ChangeOperator(EnableRelationContainment \enableRelationContainment
      , lang::ecore::Refs::Ref[Relation] \relation = \enableRelationContainment.\relation
      , lang::ecore::Refs::Id uid = \enableRelationContainment.uid
      , bool _inject = true)
  | ChangeOperator(ChangeRelationCardinality \changeRelationCardinality
      , lang::ecore::Refs::Ref[Relation] \relation = \changeRelationCardinality.\relation
      , Cardinality \newCardinality = \changeRelationCardinality.\newCardinality
      , lang::ecore::Refs::Id uid = \changeRelationCardinality.uid
      , bool _inject = true)
  | ChangeOperator(AddRelation \addRelation
      , str \name = \addRelation.\name
      , str \importedNamespace = \addRelation.\importedNamespace
      , Cardinality \cardinality = \addRelation.\cardinality
      , bool \isContainment = \addRelation.\isContainment
      , lang::ecore::Refs::Ref[Entity] \type = \addRelation.\type
      , lang::ecore::Refs::Ref[Relation] \opposite = \addRelation.\opposite
      , lang::ecore::Refs::Ref[Entity] \ownerEntity = \addRelation.\ownerEntity
      , lang::ecore::Refs::Id uid = \addRelation.uid
      , bool _inject = true)
  | ChangeOperator(RenameTable \renameTable
      , lang::ecore::Refs::Ref[Table] \tableToRename = \renameTable.\tableToRename
      , str \newName = \renameTable.\newName
      , lang::ecore::Refs::Id uid = \renameTable.uid
      , bool _inject = true)
  | ChangeOperator(MergeEntity \mergeEntity
      , lang::ecore::Refs::Ref[Entity] \firstEntityToMerge = \mergeEntity.\firstEntityToMerge
      , lang::ecore::Refs::Ref[Entity] \secondEntityToMerge = \mergeEntity.\secondEntityToMerge
      , str \newEntityName = \mergeEntity.\newEntityName
      , lang::ecore::Refs::Id uid = \mergeEntity.uid
      , bool _inject = true)
  | ChangeOperator(SplitEntityVertical \splitEntityVertical
      , lang::ecore::Refs::Ref[Entity] \entity1 = \splitEntityVertical.\entity1
      , str \entity2name = \splitEntityVertical.\entity2name
      , list[lang::ecore::Refs::Ref[Attribute]] \attributeList = \splitEntityVertical.\attributeList
      , list[lang::ecore::Refs::Ref[Relation]] \relationList = \splitEntityVertical.\relationList
      , lang::ecore::Refs::Id uid = \splitEntityVertical.uid
      , bool _inject = true)
  | ChangeOperator(RemoveGraphAttribute \removeGraphAttribute
      , lang::ecore::Refs::Ref[GraphNode] \node = \removeGraphAttribute.\node
      , lang::ecore::Refs::Id uid = \removeGraphAttribute.uid
      , bool _inject = true)
  | ChangeOperator(AddGraphEdge \addGraphEdge
      , str \name = \addGraphEdge.\name
      , str \importedNamespace = \addGraphEdge.\importedNamespace
      , lang::ecore::Refs::Ref[GraphNode] \from = \addGraphEdge.\from
      , lang::ecore::Refs::Ref[GraphNode] \to = \addGraphEdge.\to
      , list[GraphEdgeLabel] \labels = \addGraphEdge.\labels
      , lang::ecore::Refs::Id uid = \addGraphEdge.uid
      , bool _inject = true)
  | ChangeOperator(RemoveGraphEdge \removeGraphEdge
      , lang::ecore::Refs::Ref[GraphEdge] \graphEdgeToRemove = \removeGraphEdge.\graphEdgeToRemove
      , lang::ecore::Refs::Id uid = \removeGraphEdge.uid
      , bool _inject = true)
  | ChangeOperator(AddCollectionIndex \addCollectionIndex
      , lang::ecore::Refs::Ref[Collection] \collection = \addCollectionIndex.\collection
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes = \addCollectionIndex.\attributes
      , lang::ecore::Refs::Id uid = \addCollectionIndex.uid
      , bool _inject = true)
  | ChangeOperator(ChangeAttributeType \changeAttributeType
      , lang::ecore::Refs::Ref[Attribute] \attributeToChange = \changeAttributeType.\attributeToChange
      , lang::ecore::Refs::Id uid = \changeAttributeType.uid
      , bool _inject = true)
  | ChangeOperator(AddAttribute \addAttribute
      , str \name = \addAttribute.\name
      , str \importedNamespace = \addAttribute.\importedNamespace
      , DataType \type = \addAttribute.\type
      , lang::ecore::Refs::Ref[Entity] \ownerEntity = \addAttribute.\ownerEntity
      , lang::ecore::Refs::Id uid = \addAttribute.uid
      , bool _inject = true)
  | ChangeOperator(AddEntity \addEntity
      , str \name = \addEntity.\name
      , str \importedNamespace = \addEntity.\importedNamespace
      , list[EntityAttribute] \attributes = \addEntity.\attributes
      , list[Relation] \relations = \addEntity.\relations
      , list[FunctionalTag] \functionalTags = \addEntity.\functionalTags
      , list[NFunctionalTag] \nfunctionalTags = \addEntity.\nfunctionalTags
      , lang::ecore::Refs::Id uid = \addEntity.uid
      , bool _inject = true)
  | ChangeOperator(SplitEntity \splitEntity
      , lang::ecore::Refs::Ref[Entity] \entityToBeSplit = \splitEntity.\entityToBeSplit
      , Entity \firstNewEntity = \splitEntity.\firstNewEntity
      , Entity \secondNewEntity = \splitEntity.\secondNewEntity
      , lang::ecore::Refs::Id uid = \splitEntity.uid
      , bool _inject = true)
  | ChangeOperator(RemoveAttributesToIndex \removeAttributesToIndex
      , lang::ecore::Refs::Ref[Table] \table = \removeAttributesToIndex.\table
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes = \removeAttributesToIndex.\attributes
      , lang::ecore::Refs::Id uid = \removeAttributesToIndex.uid
      , bool _inject = true)
  | ChangeOperator(RemoveRelation \removeRelation
      , lang::ecore::Refs::Ref[Relation] \relationToRemove = \removeRelation.\relationToRemove
      , lang::ecore::Refs::Id uid = \removeRelation.uid
      , bool _inject = true)
  | ChangeOperator(SplitEntityHorizontal \splitEntityHorizontal
      ,str \newEntityName = \splitEntityHorizontal.\newEntityName
      ,lang::ecore::Refs::Ref[Entity] \sourceEntity = \splitEntityHorizontal.\sourceEntity
      ,lang::ecore::Refs::Ref[Attribute] \attrs = \splitEntityHorizontal.\attrs
      ,str \expression = \splitEntityHorizontal.\expression
      ,str \importedNamespace = \splitEntityHorizontal.\importedNamespace
      ,lang::ecore::Refs::Id uid = \splitEntityHorizontal.uid)
  | ChangeOperator(SplitEntityVertical \splitEntityVertical
      ,str \newEntityName = \splitEntityVertical.\newEntityName
      ,lang::ecore::Refs::Ref[Entity] \sourceEntity = \splitEntityVertical.\sourceEntity
      ,list[lang::ecore::Refs::Ref[Attribute]] \attrs = \splitEntityVertical.\attrs
      ,str \importedNamespace = \splitEntityVertical.\importedNamespace
      ,lang::ecore::Refs::Id uid = \splitEntityVertical.uid)
  ;

data RemoveGraphEdge
  = RemoveGraphEdge(lang::ecore::Refs::Ref[GraphEdge] \graphEdgeToRemove
      , lang::ecore::Refs::Id uid = noId())
  ;

data RemoveEntity
  = RemoveEntity(lang::ecore::Refs::Ref[Entity] \entityToRemove
      , lang::ecore::Refs::Id uid = noId())
  ;

data SplitEntityHorizontal
  = SplitEntityHorizontal(lang::ecore::Refs::Ref[Entity] \entity1
      , str \entity2name
      , lang::ecore::Refs::Ref[Attribute] \attribute
      , str \expression = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data RenameEntity
  = RenameEntity(lang::ecore::Refs::Ref[Entity] \entityToRename = null()
      , str \newEntityName = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data DropIndex
  = DropIndex(lang::ecore::Refs::Ref[Table] \table
      , lang::ecore::Refs::Id uid = noId())
  ;

data MigrateEntity
  = MigrateEntity(lang::ecore::Refs::Ref[Entity] \entity
      , lang::ecore::Refs::Ref[Database] \newDatabase
      , lang::ecore::Refs::Id uid = noId())
  ;

data DisableRelationContainment
  = DisableRelationContainment(lang::ecore::Refs::Ref[Relation] \relation
      , lang::ecore::Refs::Id uid = noId())
  ;

data DropCollectionIndex
  = DropCollectionIndex(lang::ecore::Refs::Ref[Collection] \collection
      , lang::ecore::Refs::Id uid = noId())
  ;

data ChangeAttributeType
  = ChangeAttributeType(ChangePrimitiveDataTypeAttribute \changePrimitiveDataTypeAttribute
      , lang::ecore::Refs::Ref[Attribute] \attributeToChange = \changePrimitiveDataTypeAttribute.\attributeToChange
      , int \maxSize = \changePrimitiveDataTypeAttribute.\maxSize
      , lang::ecore::Refs::Id uid = \changePrimitiveDataTypeAttribute.uid
      , bool _inject = true)
  | ChangeAttributeType(ChangeCustomDataTypeAttribute \changeCustomDataTypeAttribute
      , lang::ecore::Refs::Ref[Attribute] \attributeToChange = \changeCustomDataTypeAttribute.\attributeToChange
      , lang::ecore::Refs::Ref[CustomDataType] \newType = \changeCustomDataTypeAttribute.\newType
      , lang::ecore::Refs::Id uid = \changeCustomDataTypeAttribute.uid
      , bool _inject = true)
  ;

data ChangePrimitiveDataTypeAttribute
  = ChangePrimitiveDataTypeAttribute(lang::ecore::Refs::Ref[Attribute] \attributeToChange
      , int \maxSize = 0
      , lang::ecore::Refs::Id uid = noId())
  ;

data DisableBidirectionalRelation
  = DisableBidirectionalRelation(lang::ecore::Refs::Ref[Relation] \relation
      , lang::ecore::Refs::Id uid = noId())
  ;

data ChangeCustomDataTypeAttribute
  = ChangeCustomDataTypeAttribute(lang::ecore::Refs::Ref[Attribute] \attributeToChange
      , lang::ecore::Refs::Ref[CustomDataType] \newType
      , lang::ecore::Refs::Id uid = noId())
  ;

data AddIndex
  = AddIndex(lang::ecore::Refs::Ref[Table] \table
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes
      , lang::ecore::Refs::Id uid = noId())
  ;

data RenameTable
  = RenameTable(lang::ecore::Refs::Ref[Table] \tableToRename
      , str \newName = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data SplitEntityVertical
  = SplitEntityVertical(lang::ecore::Refs::Ref[Entity] \entity1
      , str \entity2name
      , list[lang::ecore::Refs::Ref[Attribute]] \attributeList
      , list[lang::ecore::Refs::Ref[Relation]] \relationList
      , lang::ecore::Refs::Id uid = noId())
  ;

data AddCollectionIndex
  = AddCollectionIndex(lang::ecore::Refs::Ref[Collection] \collection
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes
      , lang::ecore::Refs::Id uid = noId())
  ;

data EnableRelationContainment
  = EnableRelationContainment(lang::ecore::Refs::Ref[Relation] \relation
      , lang::ecore::Refs::Id uid = noId())
  ;

data RenabeGraphEdgeLabel
  = RenabeGraphEdgeLabel(lang::ecore::Refs::Ref[GraphEdge] \edge
      , str \newName = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data RemoveGraphAttribute
  = RemoveGraphAttribute(lang::ecore::Refs::Ref[GraphNode] \node
      , lang::ecore::Refs::Id uid = noId())
  ;

data SplitEntity
  = SplitEntity(lang::ecore::Refs::Ref[Entity] \entityToBeSplit
      , Entity \firstNewEntity
      , Entity \secondNewEntity
      , lang::ecore::Refs::Id uid = noId())
  ;

data EnableBidirectionalRelation
  = EnableBidirectionalRelation(lang::ecore::Refs::Ref[Relation] \relation
      , lang::ecore::Refs::Id uid = noId())
  ;

data RemoveAttributesToIndex
  = RemoveAttributesToIndex(lang::ecore::Refs::Ref[Table] \table
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes
      , lang::ecore::Refs::Id uid = noId())
  ;

data RenameCollection
  = RenameCollection(lang::ecore::Refs::Ref[Collection] \collectionToRename
      , str \newName = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data AddAttributesToIndex
  = AddAttributesToIndex(lang::ecore::Refs::Ref[Table] \table
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes
      , lang::ecore::Refs::Id uid = noId())
  ;

data RenameAttribute
  = RenameAttribute(lang::ecore::Refs::Ref[Attribute] \attributeToRename
      , str \newName
      , lang::ecore::Refs::Id uid = noId())
  ;

data ChangeRelationContainement
  = ChangeRelationContainement(lang::ecore::Refs::Ref[Relation] \relation
      , bool \newContainment
      , lang::ecore::Refs::Id uid = noId())
  ;

data MergeEntity
  = MergeEntity(lang::ecore::Refs::Ref[Entity] \firstEntityToMerge
      , lang::ecore::Refs::Ref[Entity] \secondEntityToMerge
      , str \newEntityName
      , lang::ecore::Refs::Id uid = noId())
  ;

data RemoveRelation
  = RemoveRelation(lang::ecore::Refs::Ref[Relation] \relationToRemove
      , lang::ecore::Refs::Id uid = noId())
  ;

data ChangeRelationCardinality
  = ChangeRelationCardinality(lang::ecore::Refs::Ref[Relation] \relation
      , Cardinality \newCardinality
      , lang::ecore::Refs::Id uid = noId())
  ;

data IndexSpec
  = IndexSpec(str \name
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes
      , list[lang::ecore::Refs::Ref[Relation]] \references
      , lang::ecore::Refs::Ref[Table] \table
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data Table
  = Table(str \name
      , str \importedNamespace = ""
      , util::Maybe::Maybe[IndexSpec] \indexSpec = nothing()
      , util::Maybe::Maybe[IdSpec] \idSpec = nothing()
      , lang::ecore::Refs::Ref[Database] \db = null()
      , lang::ecore::Refs::Ref[Entity] \entity = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data Database
  = Database(RelationalDB \relationalDB
      , str \name = \relationalDB.\name
      , str \importedNamespace = \relationalDB.\importedNamespace
      , list[Table] \tables = \relationalDB.\tables
      , lang::ecore::Refs::Id uid = \relationalDB.uid
      , bool _inject = true)
  | Database(ColumnDB \columnDB
      , str \name = \columnDB.\name
      , str \importedNamespace = \columnDB.\importedNamespace
      , list[Column] \columns = \columnDB.\columns
      , lang::ecore::Refs::Id uid = \columnDB.uid
      , bool _inject = true)
  | Database(DocumentDB \documentDB
      , str \name = \documentDB.\name
      , str \importedNamespace = \documentDB.\importedNamespace
      , list[Collection] \collections = \documentDB.\collections
      , lang::ecore::Refs::Id uid = \documentDB.uid
      , bool _inject = true)
  | Database(GraphDB \graphDB
      , str \name = \graphDB.\name
      , str \importedNamespace = \graphDB.\importedNamespace
      , list[GraphNode] \nodes = \graphDB.\nodes
      , list[GraphEdge] \edges = \graphDB.\edges
      , lang::ecore::Refs::Id uid = \graphDB.uid
      , bool _inject = true)
  | Database(KeyValueDB \keyValueDB
      , str \name = \keyValueDB.\name
      , str \importedNamespace = \keyValueDB.\importedNamespace
      , list[KeyValueElement] \elements = \keyValueDB.\elements
      , lang::ecore::Refs::Id uid = \keyValueDB.uid
      , bool _inject = true)
  ;

data RelationalDB
  = RelationalDB(str \name
      , list[Table] \tables
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data IdSpec
  = IdSpec(list[lang::ecore::Refs::Ref[Attribute]] \attributes
      , lang::ecore::Refs::Ref[Table] \table
      , lang::ecore::Refs::Id uid = noId())
  ;

data KeyValueDB
  = KeyValueDB(str \name
      , list[KeyValueElement] \elements
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data KeyValueElement
  = KeyValueElement(str \name
      , list[lang::ecore::Refs::Ref[Attribute]] \values
      , str \importedNamespace = ""
      , str \key = ""
      , lang::ecore::Refs::Ref[Entity] \entity = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data ColumnDB
  = ColumnDB(str \name
      , list[Column] \columns
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data Column
  = Column(str \name
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[Entity] \entity = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data DocumentDB
  = DocumentDB(str \name
      , list[Collection] \collections
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data Collection
  = Collection(str \name
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[Entity] \entity = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data GraphDB
  = GraphDB(str \name
      , list[GraphNode] \nodes
      , list[GraphEdge] \edges
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data GraphEdge
  = GraphEdge(str \name
      , list[GraphEdgeLabel] \labels
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[GraphNode] \from = null()
      , lang::ecore::Refs::Ref[GraphNode] \to = null()
      , lang::ecore::Refs::Id uid = noId())
  | GraphEdge(AddGraphEdge \addGraphEdge
      , str \name = \addGraphEdge.\name
      , str \importedNamespace = \addGraphEdge.\importedNamespace
      , lang::ecore::Refs::Ref[GraphNode] \from = \addGraphEdge.\from
      , lang::ecore::Refs::Ref[GraphNode] \to = \addGraphEdge.\to
      , list[GraphEdgeLabel] \labels = \addGraphEdge.\labels
      , lang::ecore::Refs::Id uid = \addGraphEdge.uid
      , bool _inject = true)
  ;

data AddGraphEdge
  = AddGraphEdge(str \name
      , list[GraphEdgeLabel] \labels
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[GraphNode] \from = null()
      , lang::ecore::Refs::Ref[GraphNode] \to = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data GraphEdgeLabel
  = GraphEdgeLabel(str \name
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[DataType] \type = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data GraphNode
  = GraphNode(str \name
      , list[GraphAttribute] \attributes
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[Entity] \entity = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data GraphAttribute
  = GraphAttribute(str \name
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[Attribute] \value = null()
      , lang::ecore::Refs::Id uid = noId())
  | GraphAttribute(AddGraphAttribute \addGraphAttribute
      , str \name = \addGraphAttribute.\name
      , str \importedNamespace = \addGraphAttribute.\importedNamespace
      , lang::ecore::Refs::Ref[Attribute] \value = \addGraphAttribute.\value
      , lang::ecore::Refs::Id uid = \addGraphAttribute.uid
      , bool _inject = true)
  ;

data AddGraphAttribute
  = AddGraphAttribute(str \name
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[Attribute] \value = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data RemoveAttribute
  = RemoveAttribute(lang::ecore::Refs::Ref[Attribute] \attributeToRemove
      , lang::ecore::Refs::Id uid = noId())
  ;

data RenameRelation
  = RenameRelation(lang::ecore::Refs::Ref[Relation] \relationToRename
      , str \newRelationName = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data Relation
  = Relation(str \name
      , Cardinality \cardinality
      , lang::ecore::Refs::Ref[Entity] \ownerEntity = null()
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[Entity] \type = null()
      , lang::ecore::Refs::Ref[Relation] \opposite = null()
      , bool \isContainment = false
      , lang::ecore::Refs::Id uid = noId())
  | Relation(AddRelation \addRelation
      , str \name = \addRelation.\name
      , str \importedNamespace = \addRelation.\importedNamespace
      , Cardinality \cardinality = \addRelation.\cardinality
      , bool \isContainment = \addRelation.\isContainment
      , lang::ecore::Refs::Ref[Entity] \type = \addRelation.\type
      , lang::ecore::Refs::Ref[Relation] \opposite = \addRelation.\opposite
      , lang::ecore::Refs::Ref[Entity] \ownerEntity = \addRelation.\ownerEntity
      , lang::ecore::Refs::Id uid = \addRelation.uid
      , bool _inject = true)
  ;

data AddRelation
  = AddRelation(str \name
      , Cardinality \cardinality
      , lang::ecore::Refs::Ref[Entity] \ownerEntity
      , bool \isContainment
      , lang::ecore::Refs::Ref[Entity] \type
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[Relation] \opposite = null()
      , lang::ecore::Refs::Id uid = noId())
  ;
  

data Entity
  = Entity(AddEntity \addEntity
      , str \name = \addEntity.\name
      , str \importedNamespace = \addEntity.\importedNamespace
      , list[EntityAttribute] \attributes = \addEntity.\attributes
      , list[Relation] \relations = \addEntity.\relations
      , list[FunctionalTag] \functionalTags = \addEntity.\functionalTags
      , list[NFunctionalTag] \nfunctionalTags = \addEntity.\nfunctionalTags
      , lang::ecore::Refs::Id uid = \addEntity.uid
      , bool _inject = true)
  | Entity(str \name
      , list[EntityAttribute] \attributes
      , list[Relation] \relations
      , list[FunctionalTag] \functionalTags
      , list[NFunctionalTag] \nfunctionalTags
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data EntityAttribute
  = EntityAttribute(Attribute \attribute
      , str \name = \attribute.\name
      , str \importedNamespace = \attribute.\importedNamespace
      , DataType \type = \attribute.\type
      , lang::ecore::Refs::Id uid = \attribute.uid
      , bool _inject = true)
  | EntityAttribute(CustomAttribute \customAttribute
      , str \name = \customAttribute.\name
      , str \importedNamespace = \customAttribute.\importedNamespace
      , lang::ecore::Refs::Ref[CustomDataType] \type = \customAttribute.\type
      , lang::ecore::Refs::Id uid = \customAttribute.uid
      , bool _inject = true)
  ;

data Attribute
  = Attribute(str \name
      , DataType \type
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  | Attribute(AddAttribute \addAttribute
      , str \name = \addAttribute.\name
      , str \importedNamespace = \addAttribute.\importedNamespace
      , DataType \type = \addAttribute.\type
      , lang::ecore::Refs::Ref[Entity] \ownerEntity = \addAttribute.\ownerEntity
      , lang::ecore::Refs::Id uid = \addAttribute.uid
      , bool _inject = true)
  ;

data AddAttribute
  = AddAttribute(AddCustomDataTypeAttribute \addCustomDataTypeAttribute
      , str \name = \addCustomDataTypeAttribute.\name
      , str \importedNamespace = \addCustomDataTypeAttribute.\importedNamespace
      , DataType \type = \addCustomDataTypeAttribute.\type
      , lang::ecore::Refs::Ref[Entity] \ownerEntity = \addCustomDataTypeAttribute.\ownerEntity
      , lang::ecore::Refs::Id uid = \addCustomDataTypeAttribute.uid
      , bool _inject = true)
  ;

data AddCustomDataTypeAttribute
  = AddCustomDataTypeAttribute(str \name
      , DataType \type
      , lang::ecore::Refs::Ref[Entity] \ownerEntity
      , lang::ecore::Refs::Ref[DataType] \type
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data AddEntity
  = AddEntity(str \name
      , list[EntityAttribute] \attributes
      , list[Relation] \relations
      , list[FunctionalTag] \functionalTags
      , list[NFunctionalTag] \nfunctionalTags
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data NFunctionalTag
  = NFunctionalTag(str \name
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data FunctionalTag
  = FunctionalTag(str \name
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data CustomAttribute
  = CustomAttribute(str \name
      , lang::ecore::Refs::Ref[CustomDataType] \type
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data DataType
  = DataType(CustomDataType \customDataType
      , str \name = \customDataType.\name
      , str \importedNamespace = \customDataType.\importedNamespace
      , list[CustomDataTypeItem] \elements = \customDataType.\elements
      , lang::ecore::Refs::Id uid = \customDataType.uid
      , bool _inject = true)
  | DataType(PrimitiveDataType \primitiveDataType
      , lang::ecore::Refs::Id uid = \primitiveDataType.uid
      , bool _inject = true)
  ;

data CustomDataType
  = CustomDataType(str \name
      , list[CustomDataTypeItem] \elements
      , str \importedNamespace = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data CustomDataTypeItem
  = CustomDataTypeItem(str \name
      , CustomDataTypeImplementationPackage \implementation
      , str \importedNamespace = ""
      , lang::ecore::Refs::Ref[DataType] \type = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data PrimitiveDataType
  = PrimitiveDataType(FreetextType \freetextType
      , list[NlpTask] \tasks = \freetextType.\tasks
      , lang::ecore::Refs::Id uid = \freetextType.uid
      , bool _inject = true)
  | PrimitiveDataType(PolygonType \polygonType
      , lang::ecore::Refs::Id uid = \polygonType.uid
      , bool _inject = true)
  | PrimitiveDataType(FloatType \floatType
      , lang::ecore::Refs::Id uid = \floatType.uid
      , bool _inject = true)
  | PrimitiveDataType(BigintType \bigintType
      , lang::ecore::Refs::Id uid = \bigintType.uid
      , bool _inject = true)
  | PrimitiveDataType(PointType \pointType
      , lang::ecore::Refs::Id uid = \pointType.uid
      , bool _inject = true)
  | PrimitiveDataType(StringType \stringType
      , int \maxSize = \stringType.\maxSize
      , lang::ecore::Refs::Id uid = \stringType.uid
      , bool _inject = true)
  | PrimitiveDataType(BlobType \blobType
      , lang::ecore::Refs::Id uid = \blobType.uid
      , bool _inject = true)
  | PrimitiveDataType(TextType \textType
      , lang::ecore::Refs::Id uid = \textType.uid
      , bool _inject = true)
  | PrimitiveDataType(IntType \intType
      , lang::ecore::Refs::Id uid = \intType.uid
      , bool _inject = true)
  | PrimitiveDataType(DateType \dateType
      , lang::ecore::Refs::Id uid = \dateType.uid
      , bool _inject = true)
  | PrimitiveDataType(BoolType \boolType
      , lang::ecore::Refs::Id uid = \boolType.uid
      , bool _inject = true)
  | PrimitiveDataType(DatetimeType \datetimeType
      , lang::ecore::Refs::Id uid = \datetimeType.uid
      , bool _inject = true)
  ;

data IntType
  = IntType(lang::ecore::Refs::Id uid = noId())
  ;

data BigintType
  = BigintType(lang::ecore::Refs::Id uid = noId())
  ;

data StringType
  = StringType(int \maxSize = 0
      , lang::ecore::Refs::Id uid = noId())
  ;

data BlobType
  = BlobType(lang::ecore::Refs::Id uid = noId())
  ;

data BoolType
  = BoolType(lang::ecore::Refs::Id uid = noId())
  ;

data TextType
  = TextType(lang::ecore::Refs::Id uid = noId())
  ;

data DateType
  = DateType(lang::ecore::Refs::Id uid = noId())
  ;

data PointType
  = PointType(lang::ecore::Refs::Id uid = noId())
  ;

data DatetimeType
  = DatetimeType(lang::ecore::Refs::Id uid = noId())
  ;

data PolygonType
  = PolygonType(lang::ecore::Refs::Id uid = noId())
  ;

data FloatType
  = FloatType(lang::ecore::Refs::Id uid = noId())
  ;

data FreetextType
  = FreetextType(list[NlpTask] \tasks
      , lang::ecore::Refs::Id uid = noId())
  ;

data NlpTask
  = NlpTask(str \workflowName
      , NlpTaskType \type
      , lang::ecore::Refs::Id uid = noId())
  ;

data NlpTaskType
  = RelationExtraction()
  | POSTagging()
  | Tokenisation()
  | Chunking()
  | NamedEntityRecognition()
  | Stemming()
  | SentenceSegmentation()
  | DependencyParsing()
  | PhraseExtractor()
  | CoreferenceResolution()
  | SentimentAnalysis()
  | TextClassification()
  | TermExtraction()
  | TopicModelling()
  | ParagraphSegmentation()
  | Lemmatisation()
  | NGramExtractor()
  ;

data CustomDataTypeImplementationPackage
  = CustomDataTypeImplementationPackage(str \location = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data Cardinality
  = one_many()
  | zero_many()
  | zero_one()
  | \one()
  ;