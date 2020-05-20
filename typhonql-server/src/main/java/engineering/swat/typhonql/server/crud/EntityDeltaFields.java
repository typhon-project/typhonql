package engineering.swat.typhonql.server.crud;

import java.util.List;
import java.util.Map;

public class EntityDeltaFields {
	private Map<String, String> fieldsAndSimpleRelations;
	private Map<String, List<String>> set;
	private Map<String, List<String>> add;
	private Map<String, List<String>> remove;

	public EntityDeltaFields(Map<String, String> fieldsAndSimpleRelations, Map<String, List<String>> set,
			Map<String, List<String>> add, Map<String, List<String>> remove) {
		super();
		this.fieldsAndSimpleRelations = fieldsAndSimpleRelations;
		this.set = set;
		this.add = add;
		this.remove = remove;
	}

	public Map<String, String> getFieldsAndSimpleRelations() {
		return fieldsAndSimpleRelations;
	}

	public Map<String, List<String>> getSet() {
		return set;
	}

	public Map<String, List<String>> getAdd() {
		return add;
	}

	public Map<String, List<String>> getRemove() {
		return remove;
	}

}