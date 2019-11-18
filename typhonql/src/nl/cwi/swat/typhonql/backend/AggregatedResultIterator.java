package nl.cwi.swat.typhonql.backend;

import java.util.List;

public class AggregatedResultIterator implements ResultIterator {
	
	private String type;
	private List<ResultIterator> results;
	private int index = -1;

	public AggregatedResultIterator(String type, List<ResultIterator> lst) {
		this.type = type;
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
	public String getCurrentId() {
		return results.get(index).getCurrentId();
	}

	@Override
	public Object getCurrentField(String name) {
		return results.get(index).getCurrentField(name);
	}

	@Override
	public void beforeFirst() {
		index = 0;
		for (ResultIterator iter : results) {
			iter.beforeFirst();
		}

	}



	@Override
	public String getType() {
		return this.type;
	}

}
