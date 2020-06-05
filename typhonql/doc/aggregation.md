# Design of TyphonQL aggregation features


The query partitioning of TyphonQL over various back-ends works, because filtering distributes over union of results.
In other words: filter(X + Y) == filter(X) + filter(Y). 
That is the reason we can push where-clause evaluation to native back-ends.

Unfortunately, this is not the case for the aggregation, sorting, pagination etc. features. 
For instance, we cannot sort an intermediate result, combine it with another intermediate result, and maintain sortedness; 
one would have to sort again. 
The same holds for limit, and for group by.
You can only know what to limit to after you have applied the final filtering.
And for group-by, it's only known at the very end  what the key(s) are to group-by on.

So here is an out-of-the-box-thinking proposal. 
We split a TyphonQL query in two parts, the selection/filtering part, and the other stuff.
The first part corresponds to what we currently support and is partitioned over back-ends in our iteration architecture.
The, however, instead of producing the final result table in the innermost loop, we send the result
to an (embedded) in-memory SQL database, and use *that* engine to perform aggregation, limiting, and/or sorting.

This approach has numerous advantages over "rolling our own":

- Speed: in-memory databases are better at SQL evaluation than when we would be simulating this in Java
- It's modular: independent of the current compilation pipeline (mostly), because of the splitting described above.
- Non-invasive: on the Java side, only the inner part of the iteration pipeline is affected.
- The outside world won't notice: the final result table is now simply constructed from the inner SQL result set.
- Full featured: we can use the full power of SQL to do aggregation on the result table.
- It would open up the possibility of supporting true (lazy) pagination at the cost of some memory retention.

## Candidates systems for in-memory databases

- HyperSQL http://hsqldb.org
- H2 https://www.h2database.com/html/main.html
- Apache Derby http://db.apache.org/derby/

They all have in-memory modes and JDBC interfaces.
H2 seems easy to use (https://www.h2database.com/html/cheatSheet.html), and has good licensing.
