module lang::typhonql::util::Dates

import lang::typhonql::Expr;
import DateTime;
import String;

int toInt(Tree t) = toInt("<t>");

datetime convert((DateTime)`$<DatePart date>$`) 
    = createDate(toInt(date.y), toInt(date.m), toInt(date.d));
datetime convert((DateTime)`$<DatePart date>T<TimePart time>$`) 
    = createDateTime(
        toInt(date.y), toInt(date.m), toInt(date.d),
        toInt(time.h), toInt(time.m), toInt(time.s), (ms <- time.ms ? toInt(ms) : 0)
    );


datetime convert((DateTime)`$<DatePart date>T<TimePart time> <ZoneOffset offset>$`) 
    = createDateTime(
        toInt(date.y), toInt(date.m), toInt(date.d),
        toInt(time.h), toInt(time.m), toInt(time.s), (ms <- time.ms ? toInt("<ms>"[1..]) : 0),
        (zuluTime ?  0 : toInt(offset.h)), (zuluTime ? 0 : toInt(offset.m))
    )
    when zuluTime := ((ZoneOffset)`Z` := offset);

@javaClass{lang.typhonql.util.DateTimes}
java bool onlyDate(datetime dt);

@javaClass{lang.typhonql.util.DateTimes}
java int epochMilliSeconds(datetime dt);

@javaClass{lang.typhonql.util.DateTimes}
java str printUTCDateTime(datetime dt, str format);