module lang::typhonql::util::Log

import IO;

/*
Simple Logging framework.
*/

alias Log = void(value);

void noLog(value msg) {
}

void printLog(value v) {
  println(v);
}