module lang::ecore::diff::Patch

import lang::ecore::Refs;
import lang::ecore::diff::Diff;


// assumes all isObj things have an Id (also for compositions)
&T<:node patch(type[&T<:node] meta, Patch p, &T<:node old) {
  m = objectMap(old);
  r = newRealm();

  m += ( objId: r.new(lookupType(meta, cls), prototype(meta, cls), id = objId) 
         | <Id objId, create(str cls)> <- p.edits );

  m -= ( objId: m[objId] | <Id objId, destroy()> <- p.edits );
    
  return unflatten(m[p.id], m);
} 




type[void] lookupType(type[&T<:node] meta, str name) {

}