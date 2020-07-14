/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package lang.typhonql.ide;

import java.net.URL;
import java.util.HashSet;
import java.util.Set;
import java.util.function.Consumer;
import org.eclipse.core.runtime.FileLocator;
import org.eclipse.core.runtime.Path;
import org.eclipse.core.runtime.Platform;
import org.eclipse.jface.resource.ImageDescriptor;
import org.eclipse.jface.viewers.IStructuredSelection;
import org.eclipse.jface.wizard.WizardPage;
import org.eclipse.swt.SWT;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Text;

public class TyphonSettingsPage extends WizardPage {

	private String hostValue;
	private String portValue;
	private String userNameValue;
	private String passwordValue;
	
	private final Set<String> errorFields = new HashSet<>();

	protected TyphonSettingsPage(IStructuredSelection selection) {
		super("polyStoreConnection");
		setTitle("Typhon Polystore Configuration");
		setDescription("Setup the connection information for the polystore");
		URL logo = Platform.getBundle("typhonql-ide").getResource("icons/typhon-logo-full.png");
		setImageDescriptor(ImageDescriptor.createFromURL(logo));
	}

	@Override
	public void createControl(Composite parent) {
		Composite container = new Composite(parent, SWT.NULL);
		GridLayout layout = new GridLayout();
		layout.numColumns = 2;
		layout.verticalSpacing = 9;
		container.setLayout(layout);

		addTextField(container, "host", "localhost", s -> hostValue = s);
		addTextField(container, "port", "8080", s -> portValue = s);
		addTextField(container, "username", "admin",  s -> userNameValue = s);
		addTextField(container, "password", "admin1@", s -> passwordValue = s);

		setPageComplete(true);
		setControl(container);
	}
	
	

	private Text addTextField(Composite container, String title, String defaultValue, Consumer<String> valueTarget ) {
		new Label(container, SWT.NULL).setText("Polystore " + title + ":");
		Text result = new Text(container, SWT.BORDER | SWT.SINGLE);
		result.setLayoutData( new GridData(SWT.FILL, SWT.BEGINNING, true, false));
		result.setText(defaultValue);
		valueTarget.accept(defaultValue);
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
