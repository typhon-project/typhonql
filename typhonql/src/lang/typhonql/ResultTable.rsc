module lang::typhonql::ResultTable

import lang::typhonql::util::UUID;
import List;

alias ResultTable
  = tuple[list[str] columnNames, list[list[value]] values];
