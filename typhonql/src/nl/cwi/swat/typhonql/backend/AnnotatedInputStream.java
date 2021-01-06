package nl.cwi.swat.typhonql.backend;

import java.io.InputStream;

public class AnnotatedInputStream {
	public final String blobUUID;
	public final InputStream actualStream;
	
	public AnnotatedInputStream(String blobUUID, InputStream actualStream) {
		this.blobUUID = blobUUID;
		this.actualStream = actualStream;
	}
}
