package lang.typhonql.ide;

import java.io.ObjectOutputStream.PutField;
import java.util.HashSet;
import java.util.Set;
import java.util.function.Consumer;
import org.eclipse.jface.viewers.IStructuredSelection;
import org.eclipse.jface.wizard.WizardPage;
import org.eclipse.swt.SWT;
import org.eclipse.swt.events.FocusEvent;
import org.eclipse.swt.events.FocusListener;
import org.eclipse.swt.events.PaintEvent;
import org.eclipse.swt.events.PaintListener;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Text;

public class TyphonSettingsPage extends WizardPage {

	private final IStructuredSelection selection;
	private String hostValue;
	private String portValue;
	private String userNameValue;
	private String passwordValue;
	
	private final Set<String> errorFields = new HashSet<>();

	protected TyphonSettingsPage(IStructuredSelection selection) {
		super("polyStoreConnection");
		setTitle("Typhon Polystore Configuration");
		setDescription("Setup the connection information for the polystore");
		this.selection = selection;
	}

	@Override
	public void createControl(Composite parent) {
		Composite container = new Composite(parent, SWT.NULL);
		GridLayout layout = new GridLayout();
		container.setLayout(layout);
		layout.numColumns = 2;
		layout.verticalSpacing = 9;

		addTextField(container, "host", "localhost", s -> hostValue = s);
		addTextField(container, "port", "8080", s -> portValue = s);
		addTextField(container, "username", "admin",  s -> userNameValue = s);
		addTextField(container, "password", "admin1@", s -> passwordValue = s);

		setPageComplete(false);
		setControl(container);
		container.addPaintListener(new PaintListener() {
			private boolean firstTime = true;
			@Override
			public void paintControl(PaintEvent e) {
				if (firstTime) {
					// we make sure the users  sees the config page, but after that they are fine to continue
					setPageComplete(true);
					firstTime = false;
				}
			}
		});
	}
	
	

	private Text addTextField(Composite container, String title, String defaultValue, Consumer<String> valueTarget ) {
		new Label(container, SWT.NULL).setText("Polystore " + title + ":");
		Text result = new Text(container, SWT.BORDER | SWT.SINGLE);
		result.setText(defaultValue);
		result.addModifyListener(e -> {
			String contents = result.getText();
			valueTarget.accept(contents);
			if (contents.isEmpty()) {
				errorFields.add(title);
			}
			else {
				errorFields.remove(title);
			}
			setPageComplete(errorFields.isEmpty());
			if (!errorFields.isEmpty()) {
				setErrorMessage("Missing fields: " +  errorFields);
			}
			else {
				setErrorMessage(null);
			}
		});
		return result;
	}
	
	public String getHostValue() {
		return hostValue;
	}
	
	public String getPortValue() {
		return portValue;
	}
	
	public String getUserNameValue() {
		return userNameValue;
	}
	
	public String getPasswordValue() {
		return passwordValue;
	}

}
