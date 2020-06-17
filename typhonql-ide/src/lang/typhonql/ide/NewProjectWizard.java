package lang.typhonql.ide;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.nio.charset.StandardCharsets;
import java.util.jar.Manifest;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IFolder;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IProjectDescription;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.NullProgressMonitor;
import org.eclipse.core.runtime.Path;
import org.eclipse.jface.operation.IRunnableWithProgress;
import org.eclipse.pde.core.project.IBundleProjectDescription;
import org.eclipse.pde.core.project.IBundleProjectService;
import org.eclipse.ui.wizards.newresource.BasicNewProjectResourceWizard;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceReference;
import org.osgi.framework.Version;
import org.rascalmpl.eclipse.Activator;
import org.rascalmpl.eclipse.IRascalResources;
import org.rascalmpl.eclipse.util.RascalEclipseManifest;
import org.rascalmpl.interpreter.utils.RascalManifest;

public class NewProjectWizard extends BasicNewProjectResourceWizard  {
	
	private TyphonSettingsPage settings;

	@Override
	public void addPages() {
		settings = new TyphonSettingsPage(selection);
		addPage(settings);
		super.addPages();
	}
	
	@Override
	public boolean performFinish() {
		if (!super.performFinish()) {
			return false;
		}
		
		final IProject project = getNewProject();
		
		IRunnableWithProgress job = new IRunnableWithProgress() {
			@Override
			public void run(IProgressMonitor monitor) throws InvocationTargetException,
					InterruptedException {
				try {
					BundleContext context = Activator.getInstance().getBundle().getBundleContext();
					ServiceReference<IBundleProjectService> ref = context.getServiceReference(IBundleProjectService.class);
					try {
						IBundleProjectService service = context.getService(ref);
						IBundleProjectDescription plugin = service.getDescription(project);
						plugin.setBundleName(project.getName().replaceAll("[^a-zA-Z0-9_]", "_"));
						project.setDefaultCharset("UTF-8", monitor); 


						plugin.setSymbolicName(project.getName().replaceAll("[^a-zA-Z0-9_]", "_"));
						plugin.setNatureIds(new String[] { IBundleProjectDescription.PLUGIN_NATURE, IRascalResources.ID_TERM_NATURE});
						plugin.setBundleVersion(Version.parseVersion("1.0.0"));
						plugin.setExecutionEnvironments(new String[] { "JavaSE-1.8"}); 

						IProjectDescription description = project.getDescription();
						//description.setBuildConfigs(new String[] { "org.eclipse.pde.ManifestBuilder", "org.eclipse.pde.SchemaBuilder" });
						project.setDescription(description, monitor);

						//createRascalManifest(project);
						createTyphonQLParts(project, monitor);
						plugin.apply(monitor);
					}
					finally {
						context.ungetService(ref);
					}
				} catch (CoreException e) {
					Activator.getInstance().logException("could not initialize Typhon QL project", e);
					throw new InterruptedException();
				}
			}

			private void createTyphonQLParts(IProject project, IProgressMonitor monitor) throws CoreException {
				String config = 
						"PolystoreHost: " + settings.getHostValue() + System.lineSeparator() + 
						"PolystorePort: " + settings.getPortValue() + System.lineSeparator() +
						"PolystoreUser: " + settings.getUserNameValue() + System.lineSeparator() +
						"PolystorePassword: " + settings.getPasswordValue() + System.lineSeparator();
				project.getFile(new Path("/typhon.mf"))
					.create(new ByteArrayInputStream(config.getBytes(StandardCharsets.UTF_8)), true, monitor);
				
				String example = 
						"// *** example scratch file *** " + System.lineSeparator()
						+ "// write your queries here and run them by right clicking on them" + System.lineSeparator()
						+ System.lineSeparator()
						+ "from User u" + System.lineSeparator()
						+ "select u.name" + System.lineSeparator()
						+ "where u.password == \"welcome\"" + System.lineSeparator();
						;
				project.getFile(new Path("/scratch.tql"))
					.create(new ByteArrayInputStream(example.getBytes(StandardCharsets.UTF_8)), true, monitor);
			}


			private void createRascalManifest(IProject project) throws CoreException {
				Manifest man = new RascalEclipseManifest().getDefaultManifest(project.getName());
				man.getMainAttributes().remove("Courses");
				man.getMainAttributes().remove("Main-Function");
				man.getMainAttributes().remove("Main-Module");
				
				IFolder folder = project.getFolder("META-INF");
				if (!folder.exists()) {
					if (!new File(folder.getLocation().toOSString()).mkdirs()) {
						Activator.log("could not mkdir META-INF", new IOException());
						return;
					}
				}

				IFile rascalMF = project.getFile(new Path(RascalManifest.META_INF_RASCAL_MF)) ;
				if (!rascalMF.exists()) {
					try (FileOutputStream file = new FileOutputStream(rascalMF.getLocation().toOSString())) {
						man.write(file);
					} catch (IOException e) {
						Activator.log("could not create RASCAL.MF", e);
					}
				}

				project.refreshLocal(IProject.DEPTH_INFINITE, new NullProgressMonitor());
			}
		};
		
		if (project != null) {
			try {
				getContainer().run(true, true, job);
			} catch (InvocationTargetException e) {
				Activator.getInstance().logException("could not initialize new Bird/Nescio project", e);
				return false;
			} catch (InterruptedException e) {
				return false;
			}
			return true;
		}
		
		return false;
	}

}
