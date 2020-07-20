module lang::typhonql::util::Strings

import lang::typhonql::Expr;

str unescapeQLString(Str s) = ("" | it + unescape(p) | StrChar p <- s.contents);

private str unescape(StrChar e) {
    result = "<e>";
    if (e is escaped) {
        return unescape(result);
    }
    return result;
}

private str unescape("\\\"" ) = "\"";
private str unescape("\\\\" ) = "\\";
private str unescape("\\f" ) = "\f";
private str unescape("\\b" ) = "\b";
private str unescape("\\n" ) = "\n";
private str unescape("\\r" ) = "\r";
private str unescape("\\t" ) = "\t";
private default str unescape(str s) = s;
