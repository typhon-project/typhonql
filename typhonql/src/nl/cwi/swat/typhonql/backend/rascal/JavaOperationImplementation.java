package nl.cwi.swat.typhonql.backend.rascal;

import java.util.List;
import java.util.stream.Stream;

import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.Record;


@FunctionalInterface
public interface JavaOperationImplementation {
	Stream<Object[]> processStream(List<Field> fields, Stream<Record> rows);
}
