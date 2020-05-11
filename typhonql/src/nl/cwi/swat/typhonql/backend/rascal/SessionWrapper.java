package nl.cwi.swat.typhonql.backend.rascal;

import io.usethesource.vallang.ITuple;

public class SessionWrapper implements AutoCloseable {

	private final ITuple tuple;
	private final TyphonSessionState state;

	public SessionWrapper(ITuple sessionTuple, TyphonSessionState sessionState) {
		this.tuple = sessionTuple;
		this.state = sessionState;
	}

	public ITuple getTuple() {
		return tuple;
	}

	public TyphonSessionState getState() {
		return state;
	}

	@Override
	public void close() {
		state.close();
	}

}
