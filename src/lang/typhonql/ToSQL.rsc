module lang::typhonql::ToSQL

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
:-> [0..1]     (and assume parent is always 1; no containment from multiple things)
:-> [0..*]

-> [1]      always use junction table, unless inverse of containment
-> [0..1]
-> [0..*]

Inverses (future work?)

## Change Operators

  = ChangeOperator(RenameEntity \renameEntity
      , lang::ecore::Refs::Ref[Entity] \entityToRename = \renameEntity.\entityToRename
      , str \newEntityName = \renameEntity.\newEntityName
      , lang::ecore::Refs::Id uid = \renameEntity.uid
      , bool _inject = true)
  | ChangeOperator(RenameAttribute \renameAttribute
      , lang::ecore::Refs::Ref[Attribute] \attributeToRename = \renameAttribute.\attributeToRename
      , str \newName = \renameAttribute.\newName
      , lang::ecore::Refs::Id uid = \renameAttribute.uid
      , bool _inject = true)
  | ChangeOperator(RemoveGraphEdge \removeGraphEdge
      , lang::ecore::Refs::Ref[GraphEdge] \graphEdgeToRemove = \removeGraphEdge.\graphEdgeToRemove
      , lang::ecore::Refs::Id uid = \removeGraphEdge.uid
      , bool _inject = true)
  | ChangeOperator(SplitEntity \splitEntity
      , lang::ecore::Refs::Ref[Entity] \entityToBeSplit = \splitEntity.\entityToBeSplit
      , Entity \firstNewEntity = \splitEntity.\firstNewEntity
      , Entity \secondNewEntity = \splitEntity.\secondNewEntity
      , lang::ecore::Refs::Id uid = \splitEntity.uid
      , bool _inject = true)
  | ChangeOperator(RemoveAttribute \removeAttribute
      , lang::ecore::Refs::Ref[Attribute] \attributeToRemove = \removeAttribute.\attributeToRemove
      , lang::ecore::Refs::Id uid = \removeAttribute.uid
      , bool _inject = true)
  | ChangeOperator(RenameIdentifier \renameIdentifier
      , lang::ecore::Refs::Ref[EntityIdentifier] \identifier = \renameIdentifier.\identifier
      , str \newName = \renameIdentifier.\newName
      , lang::ecore::Refs::Id uid = \renameIdentifier.uid
      , bool _inject = true)
  | ChangeOperator(DisableRelationContainment \disableRelationContainment
      , lang::ecore::Refs::Ref[Relation] \relation = \disableRelationContainment.\relation
      , lang::ecore::Refs::Id uid = \disableRelationContainment.uid
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
  | ChangeOperator(AddAttributesToIdenfifier \addAttributesToIdenfifier
      , lang::ecore::Refs::Ref[EntityIdentifier] \identifier = \addAttributesToIdenfifier.\identifier
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes = \addAttributesToIdenfifier.\attributes
      , lang::ecore::Refs::Id uid = \addAttributesToIdenfifier.uid
      , bool _inject = true)
  | ChangeOperator(AddEntity \addEntity
      , str \name = \addEntity.\name
      , str \importedNamespace = \addEntity.\importedNamespace
      , list[Attribute] \attributes = \addEntity.\attributes
      , list[Relation] \relations = \addEntity.\relations
      , EntityIdentifier \identifer = \addEntity.\identifer
      , lang::ecore::Refs::Ref[GenericList] \genericList = \addEntity.\genericList
      , lang::ecore::Refs::Id uid = \addEntity.uid
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
  | ChangeOperator(RemoveAttributesToIdenfifier \removeAttributesToIdenfifier
      , lang::ecore::Refs::Ref[EntityIdentifier] \identifier = \removeAttributesToIdenfifier.\identifier
      , list[lang::ecore::Refs::Ref[Attribute]] \attributes = \removeAttributesToIdenfifier.\attributes
      , lang::ecore::Refs::Id uid = \removeAttributesToIdenfifier.uid
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
  | ChangeOperator(EnableBidirectionalRelation \enableBidirectionalRelation
      , lang::ecore::Refs::Ref[Relation] \relation = \enableBidirectionalRelation.\relation
      , lang::ecore::Refs::Id uid = \enableBidirectionalRelation.uid
      , bool _inject = true)
  | ChangeOperator(ChangeAttributeType \changeAttributeType
      , lang::ecore::Refs::Ref[Attribute] \attributeToChange = \changeAttributeType.\attributeToChange
      , lang::ecore::Refs::Ref[DataType] \newType = \changeAttributeType.\newType
      , lang::ecore::Refs::Id uid = \changeAttributeType.uid
      , bool _inject = true)
  | ChangeOperator(DisableBidirectionalRelation \disableBidirectionalRelation
      , lang::ecore::Refs::Ref[Relation] \relation = \disableBidirectionalRelation.\relation
      , lang::ecore::Refs::Id uid = \disableBidirectionalRelation.uid
      , bool _inject = true)
  | ChangeOperator(AddRelation \addRelation
      , str \name = \addRelation.\name
      , str \importedNamespace = \addRelation.\importedNamespace
      , Cardinality \cardinality = \addRelation.\cardinality
      , bool \isContainment = \addRelation.\isContainment
      , lang::ecore::Refs::Ref[Entity] \type = \addRelation.\type
      , lang::ecore::Refs::Ref[Relation] \opposite = \addRelation.\opposite
      , lang::ecore::Refs::Id uid = \addRelation.uid
      , bool _inject = true)
  | ChangeOperator(RemoveRelation \removeRelation
      , lang::ecore::Refs::Ref[Relation] \relationToRemove = \removeRelation.\relationToRemove
      , lang::ecore::Refs::Id uid = \removeRelation.uid
      , bool _inject = true)
  | ChangeOperator(AddAttribute \addAttribute
      , str \name = \addAttribute.\name
      , str \importedNamespace = \addAttribute.\importedNamespace
      , lang::ecore::Refs::Ref[DataType] \type = \addAttribute.\type
      , lang::ecore::Refs::Id uid = \addAttribute.uid
      , bool _inject = true)
  | ChangeOperator(AddIdentifier \addIdentifier
      , lang::ecore::Refs::Ref[Entity] \entity = \addIdentifier.\entity
      , str \name = \addIdentifier.\name
      , lang::ecore::Refs::Id uid = \addIdentifier.uid
      , bool _inject = true)
  | ChangeOperator(RemoveIdentifier \removeIdentifier
      , lang::ecore::Refs::Ref[EntityIdentifier] \entityIdentifier = \removeIdentifier.\entityIdentifier
      , lang::ecore::Refs::Id uid = \removeIdentifier.uid
      , bool _inject = true)
  | ChangeOperator(RenameRelation \renameRelation
      , lang::ecore::Refs::Ref[Relation] \relationToRename = \renameRelation.\relationToRename
      , str \newRelationName = \renameRelation.\newRelationName
      , lang::ecore::Refs::Id uid = \renameRelation.uid
      , bool _inject = true)



*/