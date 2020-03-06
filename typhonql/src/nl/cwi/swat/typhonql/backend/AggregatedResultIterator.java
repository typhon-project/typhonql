package nl.cwi.swat.typhonql.backend;

import java.util.List;

public class AggregatedResultIterator implements ResultIterator {
	
	private List<ResultIterator> results;
	private int index = -1;

	public AggregatedResultIterator(List<ResultIterator> lst) {
		this.results = lst;
		beforeFirst();
	}

	@Override
	public void nextResult() {
		if (results.get(index).hasNextResult()) {
			results.get(index).nextResult();
		} else {
			index ++;
			results.get(index).nextResult();
		}
	}
	
	@Override
	public boolean hasNextResult() {
		return hasNextResult(index);
	}

	private boolean hasNextResult(int i) {
		if (results.get(i).hasNextResult()) {
			return true;
		} else {
			if (i == results.size() -1) {
				return false;
			}
			else {
				return hasNextResult(i + 1);
			}
		}
	}

	@Override
	public String getCurrentId(String label, String type) {
		return results.get(index).getCurrentId(label, type);
	}

	@Override
	public Object getCurrentField(String label, String type, String name) {
		return results.get(index).getCurrentField(label, type, name);
	}

	@Override
	public void beforeFirst() {
		index = 0;
		for (ResultIterator iter : results) {
			iter.beforeFirst();
		}

	}

	@Override
	public Object getCurrentField(String fullyQualifiedName) {
		return results.get(index).getCurrentField(fullyQualifiedName);
	}


}
