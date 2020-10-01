package nl.cwi.swat.typhonql.backend.rascal;

import java.util.List;
import java.util.stream.Collectors;

import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.Record;

public class AggregationOperators {
	
	
	/*
	 * Todo: these should use the cross-back-end-java versions of the
	 * typhonql types that we support.
	 */
	
	public static Object count(List<Record> vals) {
		return vals.size();
	}
	
	public static Object sum(List<Record> vals, Field field) {
		return vals.stream().collect(Collectors.summingLong((Record x) -> ((Long)x.getObject(field))));
	}
	

	public static Object avg(List<Record> vals, Field field) {
		return vals.stream().collect(Collectors.averagingLong((Record x) -> ((Long)x.getObject(field))));
	}

	
	public static Object max(List<Record> vals, Field field) {
		return vals.stream().collect(Collectors.maxBy(
				(Record x, Record y) ->  ((Long)x.getObject(field)).compareTo((Long)y.getObject(field))
		));
	}

	public static Object min(List<Record> vals, Field field) {
		return vals.stream().collect(Collectors.minBy(
				(Record x, Record y) ->  ((Long)x.getObject(field)).compareTo((Long)y.getObject(field))
		));
	}
	

}
