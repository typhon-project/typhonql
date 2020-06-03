package nl.cwi.swat.typhonql.backend;

import java.io.Closeable;

public class Closables {
	
	@SuppressWarnings("unchecked")
	public static <T extends Exception> void autoCloseAll(Iterable<? extends AutoCloseable> all, Class<T> exceptionType) throws T {
		T firstException = null;
		Exception unexpected = null;
		for (AutoCloseable ses : all) {
			try {
				ses.close();
			} catch (Exception e) {
				if (exceptionType.isInstance(e)) {
                    if (firstException == null) {
                        firstException = (T)e;
                    }
				}
				else if (unexpected == null) {
					unexpected = e;
				}
			}
		}
		if (firstException != null) {
			throw firstException;
		}
		if (unexpected != null) {
			throw new RuntimeException("Unexpected exception thrown", unexpected);
			
		}
	}

	public static <T extends Exception> void closeAll(Iterable<? extends Closeable> all, Class<T> exceptionType) throws T {
		T firstException = null;
		Exception unexpected = null;
		for (AutoCloseable ses : all) {
			try {
				ses.close();
			} catch (Exception e) {
				if (exceptionType.isInstance(e)) {
                    if (firstException == null) {
                        firstException = (T)e;
                    }
				}
				else if (unexpected == null) {
					unexpected = e;
				}
			}
		}
		if (firstException != null) {
			throw firstException;
		}
		if (unexpected != null) {
			throw new RuntimeException("Unexpected exception thrown", unexpected);
			
		}
	}
}
