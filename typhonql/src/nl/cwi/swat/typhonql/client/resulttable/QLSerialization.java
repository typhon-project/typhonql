package nl.cwi.swat.typhonql.client.resulttable;

import java.io.IOException;
import java.io.InputStream;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.stream.Stream;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;

import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonFactoryBuilder;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.json.JsonReadFeature;
import com.fasterxml.jackson.core.json.JsonWriteFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;


public class QLSerialization {



	public static final ObjectMapper mapper;

	static {
		SimpleModule customSerializers = new SimpleModule();
		customSerializers.addSerializer(Geometry.class, new GeometrySerializer());
		customSerializers.addSerializer(Polygon.class, new GeometrySerializer());
		customSerializers.addSerializer(Point.class, new GeometrySerializer());
		customSerializers.addSerializer(LocalDate.class, new LocalDateSerializer());
		customSerializers.addSerializer(Instant.class, new InstantSerializer());
		customSerializers.addSerializer(InputStream.class, new ByteStreamSerializer());
		customSerializers.addSerializer(new StreamSerializer());

		JsonFactory factory = new JsonFactoryBuilder()
				.enable(JsonWriteFeature.WRITE_NUMBERS_AS_STRINGS)
				.build();

		mapper = new ObjectMapper(factory)
				.disable(JsonGenerator.Feature.AUTO_CLOSE_TARGET)
				;
		mapper.registerModule(customSerializers);
	}

	@SuppressWarnings("serial")
	private static class GeometrySerializer extends StdSerializer<Geometry> {
		public GeometrySerializer() {
			super(Geometry.class);
		}

		@Override
		public void serialize(Geometry value, JsonGenerator gen, SerializerProvider provider)
				throws IOException {
			gen.writeString(value.toText());
		}
		
	}

	@SuppressWarnings("serial")
	public static class LocalDateSerializer extends StdSerializer<LocalDate> {
		
		public LocalDateSerializer() {
			super(LocalDate.class);
		}

		@Override
		public void serialize(LocalDate value, JsonGenerator gen, SerializerProvider provider)
				throws IOException {
			gen.writeString(value.format(DateTimeFormatter.ISO_LOCAL_DATE));
		}
	}
	
	
	@SuppressWarnings("serial")
	public static class InstantSerializer extends StdSerializer<Instant> {
		
		public InstantSerializer() {
			super(Instant.class);
		}

		@Override
		public void serialize(Instant value, JsonGenerator gen, SerializerProvider provider)
				throws IOException {
			gen.writeString(DateTimeFormatter.ISO_INSTANT.format(value));
		}
	}

	@SuppressWarnings("serial")
	public static class ByteStreamSerializer extends StdSerializer<InputStream> {

		protected ByteStreamSerializer() {
			super(InputStream.class);
		}

		@Override
		public void serialize(InputStream value, JsonGenerator gen, SerializerProvider provider) throws IOException {
			gen.writeBinary(value, -1);
		}

	}
	
	
	@SuppressWarnings({ "serial" })
	private static final class StreamSerializer extends StdSerializer<Stream<?>> {
		
		private StreamSerializer() {
			super(Stream.class, true);
		}


		@Override
		public void serialize(Stream<?> value, JsonGenerator gen, SerializerProvider provider)
				throws IOException {
			gen.writeStartArray();
			try {
				value.forEachOrdered(element -> {
					try {
						if (element instanceof Object[]) {
							Object[] obs = (Object[]) element;
							gen.writeStartArray(obs.length);
							for (Object o : obs) {
								gen.writeObject(o);
							}
							gen.writeEndArray();

						} else {
							gen.writeObject(element);
						}
					} catch (IOException e) {
						throw new RuntimeException(e);
					}
				});
			}
			finally {
				gen.writeEndArray();
			}
		}


	}

}
