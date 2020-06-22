package lang.typhonql.ide;

import org.rascalmpl.eclipse.Activator;
import io.usethesource.impulse.builder.ProjectNatureBase;
import io.usethesource.impulse.runtime.IPluginLog;

public class Nature  extends ProjectNatureBase {

	@Override
	public String getNatureID() {
		return "typhonql_nature";
	}

	@Override
	public String getBuilderID() {
		return null;
	}

	@Override
	public IPluginLog getLog() {
		return Activator.getInstance();
	}

	@Override
	protected void refreshPrefs() {
		
	}


}