package nl.cwi.swat.typhonql.backend.rascal;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import io.usethesource.vallang.IRelation;
import io.usethesource.vallang.ISet;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import nl.cwi.swat.typhonql.backend.EntityModel;
import nl.cwi.swat.typhonql.backend.TyphonType;

public class EntityModelReader {
	public static List<EntityModel> fromRascalRelation(List<String> types, IRelation<ISet> rel) {

		Iterator<IValue> relIter = rel.iterator();

		Map<String, EntityModel> models = new HashMap<>();

		while (relIter.hasNext()) {
			ITuple tuple = (ITuple) relIter.next();
			IString name = (IString) tuple.get(0);
			IRelation<ISet> attributes = (IRelation<ISet>) tuple.get(1);
			Map<String, TyphonType> attributesMap = new HashMap<String, TyphonType>();

			Iterator<IValue> attIter = attributes.iterator();

			while (attIter.hasNext()) {
				ITuple att = (ITuple) attIter.next();
				String attName = ((IString) att.get(0)).getValue();
				String attType = ((IString) att.get(1)).getValue();
				attributesMap.put(attName, TyphonType.valueOf(attType.toUpperCase()));
			}

			models.put(name.getValue(), new EntityModel(name.getValue(), attributesMap));
		}

		relIter = rel.iterator();

		while (relIter.hasNext()) {
			ITuple tuple = (ITuple) relIter.next();
			
			IString name = (IString) tuple.get(0);
			IRelation<ISet> relations = (IRelation<ISet>) tuple.get(2);
			
			Map<String, EntityModel> relationsMap = new HashMap<String, EntityModel>();

			Iterator<IValue> relationIter = relations.iterator();

			while (relationIter.hasNext()) {
				ITuple relation = (ITuple) relationIter.next();
				String relName = ((IString) relation.get(0)).getValue();
				String relEntitName = ((IString) relation.get(1)).getValue();
				relationsMap.put(relName, models.get(relEntitName));
			}
			
			relationsMap.get(name.getValue()).setEntities(relationsMap);
		}
		
		List<EntityModel> result = new ArrayList<EntityModel>();
		
		for (String type : types)
			result.add(models.get(type));
		return result;

	}
}
