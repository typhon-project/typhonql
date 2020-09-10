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

package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Spliterator;
import java.util.Spliterators;
import java.util.concurrent.BlockingDeque;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingDeque;
import java.util.function.Consumer;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.client.resulttable.StreamingResultTable;

public class Runner {
	
	public static ResultTable computeResultTable(List<Consumer<List<Record>>> script, List<Path> paths) {
		List<List<Record>> result = new ArrayList<List<Record>>();
		script.add((List<Record> row) -> {
			result.add(project(row, paths));
		});
		script.get(0).accept(new ArrayList<Record>());
		return toResultTable(paths, result);
	}
	
	private static final ExecutorService WORKERS = Executors.newCachedThreadPool();
	
	public static StreamingResultTable computeResultStream(List<Consumer<List<Record>>> script, List<Path> paths) {
		List<String> columnNames = buildColumnNames(paths);
		return new StreamingResultTable(columnNames, StreamSupport.stream(() -> {
			BlockingDeque<Object[]> incomingRecords = new LinkedBlockingDeque<>(); 
			
			// once the stream has a terminal operator, we start the db operations
			// on the background, so that we can have the iterator block until results are ready
			WORKERS.execute(() -> {
				try {
					List<Field> fields = paths.stream().map(p -> toField(p)).collect(Collectors.toList());
                    script.add(rows -> projectRaw(rows, fields, incomingRecords));
                    script.get(0).accept(new ArrayList<Record>());
				}
				finally {
					try {
						incomingRecords.putLast(new Object[0]);
					} catch (InterruptedException e) {
					}
				}
			});

			return Spliterators.spliteratorUnknownSize(new Iterator<Object[]>() {
				private volatile Object[] current = null;
				@Override
				public boolean hasNext() {
					Object[] value = current;
					if (value != null && value.length == 0) {
						return false;
					}
					try {
						return (current = incomingRecords.takeFirst()).length != 0;
					} catch (InterruptedException e) {
						current = new Object[0];
						return false;
					}
				}

				@Override
				public Object[] next() {
					Object[] result = current;
					if (result == null || result.length == 0) {
						throw new NoSuchElementException();

					}
					return result;
				}

			}, Spliterator.ORDERED | Spliterator.NONNULL);
		}, 0, false));
	}
	
	public static void executeUpdates(List<Consumer<List<Record>>> script) {
		script.get(0).accept(new ArrayList<Record>());
	}

	private static ResultTable toResultTable(List<Path> paths, List<List<Record>> result) {
		List<String> columnNames = buildColumnNames(paths);
		List<Field> fields = paths.stream().map(p -> toField(p)).collect(Collectors.toList());
		List<List<Object>> values = toValues(fields, result);
		return new ResultTable(columnNames, values);
	}
	
	

	private static Field toField(Path p) {
		return new Field(p.getDbName(), p.getVar(), p.getEntityType(), p.getSelectors()[0]);
	}

	private static List<List<Object>> toValues(List<Field> fields, List<List<Record>> rs) {
		List<List<Object>> vs = new ArrayList<>();
		for (List<Record> records : rs) {
			List<Object> os = new ArrayList<>();
			for (Record r : records) {
				for (Field f : fields) {
					os.add(r.getObject(f));
				}
			}
			vs.add(os);
		}
		return vs;
	}

	private static List<Record> project(List<Record> row, List<Path> paths) {
		List<Record> ls = new ArrayList<Record>();
		for (Record r : row) {
			ls.add(project(r, paths));
		}
		return ls;
	}

	private static void projectRaw(List<Record> rows, List<Field> fields, BlockingDeque<Object[]> results) {
		try {
			for (Record r: rows) {
				results.putLast(projectRaw(r, fields));
			}
		} catch (InterruptedException e) {
		}
	}


	private static Field match(Record r, Path p) {
		for (Field f : r.getObjects().keySet()) {
			if (f.getLabel().equals(p.getVar()) && f.getType().equals(p.getEntityType())
					&& f.getAttribute().equals(p.getSelectors()[0]))
				return f;

		}
		return null;
	}
	
	private static Object[] projectRaw(Record r, List<Field> fields) {
		Object[] result = new Object[fields.size()];
		for (int i = 0; i < result.length; i++) {
			result[i] = r.getObject(fields.get(i));
		}
		return result;
	}

	private static Record project(Record r, List<Path> paths) {
		Map<Field, Object> os = new HashMap<>();
		for (Path p : paths) {
			Field f = match(r, p);
			if (f != null) {
				os.put(f, r.getObjects().get(f));
			}
		}
		return new Record(os);
	}

	private static List<String> buildColumnNames(List<Path> paths) {
		List<String> names = new ArrayList<String>();
		for (Path path : paths) {
			List<String> name = new ArrayList<String>();
			name.add(path.getVar());
			for (String selector : path.getSelectors()) {
				name.add(selector);
			}
			names.add(String.join(".", name));
		}
		return names;
	}


}
