package nl.cwi.swat.typhonql.client.resulttable;

import java.io.IOException;
import java.io.InputStream;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.stream.Stream;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;
import com.fasterxml.jackson.databind.type.TypeFactory;


public class QLSerialization {


	public static final ObjectMapper mapper;

	static {
		SimpleModule customSerializers = new SimpleModule();
		customSerializers.addSerializer(Geometry.class, new GeometrySerializer());
		customSerializers.addSerializer(Polygon.class, new GeometrySerializer());
		customSerializers.addSerializer(Point.class, new GeometrySerializer());
		customSerializers.addSerializer(LocalDate.class, new LocalDateSerializer());
		customSerializers.addSerializer(LocalDateTime.class, new LocalDateTimeSerializer());
		customSerializers.addSerializer(InputStream.class, new ByteStreamSerializer());

		mapper = new ObjectMapper().configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, false);
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
	public static class LocalDateTimeSerializer extends StdSerializer<LocalDateTime> {
		
		public LocalDateTimeSerializer() {
			super(LocalDateTime.class);
		}

		@Override
		public void serialize(LocalDateTime value, JsonGenerator gen, SerializerProvider provider)
				throws IOException {
			gen.writeString(value.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
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

}
