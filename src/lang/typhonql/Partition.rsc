module lang::ladon::Partition

data Plan
  = plan(Query combine, rel[Conf, Query] delegates);

alias Dist = rel[Conf conf, str var];


Plan queryPlan(Query q, Schema s) = plan(recombine(q, d), partition(q, d))
  when
    Dist d := placement(q, s);


rel[Conf, Query] partition(Query q, Dist d) = { <c, restrict(q, d[c], d)> | Conf c <- d<conf> };
  

Dist placement(Query q, Schema s) 
  = { <c, x> | let(str e, str x) <- q.bindings, Conf c <- s.entities, entity(e, _) := s.entities[c] };


bool isLocal(Clause w,  set[str] xs) = !(/attr(str y, _) := w && y notin xs);


// a clause is cross db, when not all of it's referred attrs are on a single conf
bool isCross(Clause w, Dist d) = !(Conf c <- d<conf> && xs <= d[c])
  when
    set[str] xs := { x | /attr(str x, _) := w };

Query recombine(Query q, Dist d) = q[where = [ w | Clause w <- q.where, isCross(w, d) ] ];

Query restrict(Query q, set[str] xs, Dist d) 
  = from([ b | Binding b <- q.bindings, b.name in xs ],  // keep only bindings for xs
  
       // add to select if not already there
       // NB: only add x out of xs to result set when x *also* participates in a
       // cross clause. Otherwise there's no need to return it.
       select = dup([ a | Clause w <- q.where, isCross(w, d), /a:attr(str x, _) := w, x in xs ]
           + [ a | a:attr(str x, _) <- q.select, x in xs ]),  
       
       // keep only clauses that only are on xs in some way
       where = [ w | Clause w <- q.where, isLocal(w, xs) ]
    );

str pp(plan(Query q0, rel[Conf, Query] ds)) 
  = "<pp(q0)>
    '
    '<for (<Conf c, Query q> <- ds) {>
    '<pp(c)>
    '<pp(q)>
    '<}>"; 
