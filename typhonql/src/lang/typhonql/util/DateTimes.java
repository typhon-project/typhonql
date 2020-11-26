package lang.typhonql.util;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.OffsetTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.TimeUnit;

import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IDateTime;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValueFactory;

public class DateTimes {
	private final IValueFactory vf;
	
	public DateTimes(IValueFactory vf) {
		this.vf = vf;
	}
	
	public IBool onlyDate(IDateTime dt) {
		return vf.bool(dt.isDate());
	}
	
	public IInteger epochMilliSeconds(IDateTime dt) {
		return vf.integer(toOffsetDateTime(dt).toInstant().toEpochMilli());
	}
	
	private static OffsetDateTime toOffsetDateTime(IDateTime dt) {
		if (dt.isDateTime()) {
            return OffsetDateTime.of(
                    dt.getYear(),
                    dt.getMonthOfYear(),
                    dt.getDayOfMonth(),
                    dt.getHourOfDay(),
                    dt.getMinuteOfHour(),
                    dt.getSecondOfMinute(),
                    (int)TimeUnit.MILLISECONDS.toNanos(dt.getMillisecondsOfSecond()),
                    ZoneOffset.ofHoursMinutes(dt.getTimezoneOffsetHours(), dt.getTimezoneOffsetMinutes())
            );
		}
		return LocalDate.of(dt.getYear(), dt.getMonthOfYear(), dt.getDayOfMonth()).atTime(OffsetTime.of(0, 0, 0, 0, ZoneOffset.UTC));
		
	}
	
	public IString printUTCDateTime(IDateTime dt, IString format) {
		DateTimeFormatter formatter =  DateTimeFormatter.ofPattern(format.getValue());
		return vf.string(formatter.format(toOffsetDateTime(dt).withOffsetSameInstant(ZoneOffset.UTC)));
	}
	
}
