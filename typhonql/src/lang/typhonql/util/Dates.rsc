module lang::typhonql::util::Dates

import lang::typhonql::Expr;
import DateTime;
import String;
import ParseTree;

int toInt(Tree t) = toInt(removeZeroPrefix("<t>"));

str removeZeroPrefix(str s) {
    if (/^0+<after:.+>$/ := s) {
        return after;
    }
    return s;
}

datetime convert((Expr)`<DateTime dt>`) = convert(dt);
datetime convert((DateTime)`<JustDate dt>`) = convert(dt);
datetime convert((DateTime)`<DateAndTime dt>`) = convert(dt);

datetime convert((JustDate)`$<DatePart date>$`) 
    = createDate(toInt(date.y), toInt(date.m), toInt(date.d));

datetime convert((DateAndTime)`$<DatePart date>T<TimePart time>$`) 
    = createDateTime(
        toInt(date.y), toInt(date.m), toInt(date.d),
        toInt(time.h), toInt(time.m), toInt(time.s), ((ms <- time.ms) ? toInt(ms) : 0)
    );

int factor((ZoneOffset)`-<Hour _>:<Minute _>`) = -1;
int factor((ZoneOffset)`+<Hour _>:<Minute _>`) = 1;

datetime convert((DateAndTime)`$<DatePart date>T<TimePart time><ZoneOffset offset>$`) 
    = createDateTime(
        toInt(date.y), toInt(date.m), toInt(date.d),
        toInt(time.h), toInt(time.m), toInt(time.s), msToInt(time.ms),
        (zuluTime ?  0 : factor(offset) * toInt(offset.h)), (zuluTime ? 0 : factor(offset) * toInt(offset.m))
    )
    when zuluTime := ((ZoneOffset)`Z` := offset);
    
int msToInt(Millisecond? ms) {
    if (m <- ms) {
        return toInt(removeZeroPrefix("<m>"[1..]));
    }
    return 0;
}

default datetime convert(Tree t) {
    throw "Forgot to support <t>";
}

@javaClass{lang.typhonql.util.DateTimes}
java bool onlyDate(datetime dt);

@javaClass{lang.typhonql.util.DateTimes}
java int epochMilliSeconds(datetime dt);

@javaClass{lang.typhonql.util.DateTimes}
java str printUTCDateTime(datetime dt, str format);