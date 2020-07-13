package nl.cwi.swat.typhonql.backend;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.regex.Pattern;

public abstract class Engine {
	protected final ResultStore store;
	protected final Map<String, UUID> uuids;
	protected final List<Consumer<List<Record>>> script;
	protected final List<Runnable> updates;
	protected static final Pattern QL_PARAMS = Pattern.compile("\\$\\{([\\w\\-]*?)\\}");

	public Engine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, UUID> uuids) {
		this.store = store;
		this.script = script;
		this.updates = updates;
		this.uuids = uuids;
	}
	
}