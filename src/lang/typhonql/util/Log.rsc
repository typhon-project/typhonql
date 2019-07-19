module lang::typhonql::util::Log

import IO;

alias Log = void(value);

void noLog(value msg) {
}

void printLog(value v) {
  println(v);
}