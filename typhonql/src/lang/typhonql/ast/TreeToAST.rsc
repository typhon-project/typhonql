// extract of the lang::rascal::grammar::SyntaxTreeGenerator file in the rascal library
module lang::typhonql::ast::TreeToAST

import Grammar;
import lang::rascal::grammar::definition::Parameters;
import ParseTree;

import IO;
import String;
import List;
import Set;
import util::Math;

data AST 
  = ast(str name, set[Sig] sigs) 
  | leaf(str name)
  ;
  
data Sig 
  = sig(str name, list[Arg] args)
  ;
  
data Arg 
  = arg(str typ, str name, bool isOptional = false);

private str header = "/*******************************************************************************
                     ' * Typhon QL license?
                     ' *******************************************************************************/";

public set[AST] grammarToASTModel(str pkg, Grammar g) {
  map[str, set[Sig]] m = ();
  set[Sig] sigs = {};
  set[AST] asts = {};
  
  g = visit(g) {
    case conditional(s,_) => s
  }
  
  for (/p:prod(label(c,sort(name)),_,_) := g) 
     m[name]?sigs += {sig(capitalize(c), productionArgs(pkg, p))};

  for (/p:prod(label(c,\parameterized-sort(name,[Symbol _:str _(str a)])),_,_) := g) 
     m[name + "_" + a]?sigs += {sig(capitalize(c), productionArgs(pkg, p))};

  for (sn <- m) 
    asts += ast(sn, m[sn]);
    
  for (/p:prod(\lex(s),_,_) := g) 
     asts += leaf(s);
     
  for (/p:prod(label(_,\lex(s)),_,_) := g) 
     asts += leaf(s);
 
  for (/p:prod(label(_,\parameterized-lex(s,[Symbol _:str _(str a)])),_,_) := g) 
     asts += leaf(s + "_" + a);
  
  return asts;
}

public void grammarToJavaAPI(loc outdir, str pkg, Grammar g) {
  arbSeed(42);
  model = grammarToASTModel(pkg, g);
  grammarToVisitor(outdir, pkg, model);
  grammarToASTClasses(outdir, pkg, model);
}

public void grammarToVisitor(loc outdir, str pkg, set[AST] asts, str licenseHeader = header) {
  ivisit = "package <pkg>;
           '
           'public interface IASTVisitor\<T\> {
           '<for (ast(sn, sigs) <- sort(asts), sig(cn, args) <- sort(sigs)) {>
           '  public T visit<sn><cn>(<sn>.<cn> x);
           '<}>
           '<for (leaf(sn) <- sort(asts)) {>
           '  public T visit<sn>Lexical(<sn>.Lexical x);
           '<}>
           '}";

  loggedWriteFile(outdir + "/IASTVisitor.java", ivisit, licenseHeader);

  nullVisit = "package <pkg>;
              '
              'public class NullASTVisitor\<T\> implements IASTVisitor\<T\> {
              '<for (ast(sn, sigs) <- sort(asts), sig(cn, args) <- sort(sigs)) {>
              '  public T visit<sn><cn>(<sn>.<cn> x) { 
              '    return null; 
              '  }
              '<}>
              '<for (leaf(sn) <- sort(asts)) {>
              '  public T visit<sn>Lexical(<sn>.Lexical x) { 
              '    return null; 
              '  }
              '<}>
              '}";

   loggedWriteFile(outdir + "/NullASTVisitor.java", nullVisit, licenseHeader);
}

public void grammarToASTClasses(loc outdir, str pkg, set[AST] asts, str licenseHeader = header) {
  for (a <- sort(asts)) {
     class = classForSort(pkg, ["io.usethesource.vallang.IConstructor", "io.usethesource.vallang.ISourceLocation"], a);
     loggedWriteFile(outdir + "/<a.name>.java", class, licenseHeader); 
  }
}

public str classForSort(str pkg, list[str] imports, AST ast) {
  allArgs = { arg | /Arg arg <- ast };
  return "package <pkg>;
         '
         '<for (i <- sort(imports)) {>
         'import <i>;<}>
         '
         '@SuppressWarnings(value = {\"unused\"})
         'public abstract class <ast.name> extends AbstractAST {
         '  public <ast.name>(ISourceLocation src, IConstructor node) {
         '    super(src /* we forget node on purpose */);
         '  }
         '
         '  <for (a:arg(typ, lab) <- sort(allArgs)) { clabel = capitalize(lab); >
         '  public boolean has<clabel>() {
         '    return false;
         '  }
         '
         '  public <makeMonotonic(a)> get<clabel>() {
         '    throw new UnsupportedOperationException();
         '  }<}>
         '
         '  <if (leaf(_) := ast) {><lexicalClass(ast.name)><}>
         '
         '  <for (ast is ast, Sig sig <- sort(ast.sigs)) { >
         '  public boolean is<sig.name>() {
         '    return false;
         '  }
         '
         '  <classForProduction(pkg, ast.name, sig)><}>
         '}"; 
}

public str classForProduction(str pkg, str super, Sig sig) {
  return "static public class <sig.name> extends <super> {
         '  // Production: <sig>
         '
         '  <for (arg(typ, name) <- sig.args) {>
         '  private final <typ> <name>;<}>
         '
         '  <construct(sig)>
         '
         '  @Override
         '  public boolean is<sig.name>() { 
         '    return true; 
         '  }
         '
         '  @Override
         '  public \<T\> T accept(IASTVisitor\<T\> visitor) {
         '    return visitor.visit<super><sig.name>(this);
         '  }
         '
         '  @Override
         '  public boolean equals(Object o) {
         '    if (!(o instanceof <sig.name>)) {
         '      return false;
         '    }        
         '    <sig.name> tmp = (<sig.name>) o;
         '    return true <for (a <- sig.args) {>&& <nullableEquals(a)> <}>; 
         '  }
         ' 
         '  @Override
         '  public int hashCode() {
         '    return <arbPrime(1000)> <for (a <- sig.args) { >+ <arbPrime(1000)> * <nullableHashCode(a)> <}>; 
         '  } 
         '
         '  <for (a:arg(typ, name, isOptional = isopt) <- sig.args) { cname = capitalize(name); >
         '  @Override
         '  public <makeMonotonic(a)> get<cname>() {
         '    return this.<name>;
         '  }
         '
         '  @Override<if (isopt) {> @org.checkerframework.checker.nullness.qual.EnsuresNonNullIf(expression=\"get<cname>()\", result=true) <}>
         '  public boolean has<cname>() {
         '    return <if (isopt) {>this.<name> != null<} else {>true<}>;
         '  }<}>	
         '
         '}";
}

private str makeMonotonic(arg(str typ, _, isOptional = true)) = replaceAll(typ, "Nullable", "MonotonicNonNull");
private str makeMonotonic(arg(str typ, _, isOptional = false)) = typ;

private str nullableHashCode(arg(_, str name, isOptional = true)) = "java.util.Objects.hashCode(<name>)";
private str nullableHashCode(arg(_, str name, isOptional = false)) = "<name>.hashCode()";

private str nullableEquals(arg(_, str name, isOptional = true)) = "java.util.Objects.equals(tmp.<name>, this.<name>)";
private str nullableEquals(arg(_, str name, isOptional = false)) = "tmp.<name>.equals(this.<name>)";

public str lexicalClass(str name) {
  return "static public class Lexical extends <name> {
         '  private final java.lang.String string;
         '  public Lexical(ISourceLocation src, IConstructor node, java.lang.String string) {
         '    super(src, node);
         '    this.string = string;
         '  }
         '  public java.lang.String getString() {
         '    return string;
         '  }
         '
         '  @Override
         '  public int hashCode() {
         '    return string.hashCode();
         '  }
         '
         '  @Override
         '  public boolean equals(Object o) {
         '    return o instanceof Lexical && ((Lexical) o).string.equals(string);  
         '  }
         '
         '  public java.lang.String toString() {
         '    return string;
         '  }
         '  public \<T\> T accept(IASTVisitor\<T\> v) {
         '    return v.visit<name>Lexical(this);
         '  }
         '}";
}


list[Arg] productionArgs(str pkg, Production p) {
   str l = "java.util.List";
   return for (label(str name, Symbol sym) <- p.symbols) {
     a = arg("", name);
     if (\opt(Symbol ss) := sym) {
        a.isOptional = true;
        sym = ss;
     }
     switch (sym) {
       case \sort(str s): a.typ = "<pkg>.<s>"; 
       case \lex(str s): a.typ = "<pkg>.<s>"; 
       case \iter(\sort(str s)): a.typ = "<l>\<<pkg>.<s>\>";  
       case \iter-star(\sort(str s)): a.typ = "<l>\<<pkg>.<s>\>";
       case \iter-seps(\sort(str s), _): a.typ = "<l>\<<pkg>.<s>\>";
       case \iter-star-seps(\sort(str s), _): a.typ = "<l>\<<pkg>.<s>\>";
       case \iter(\lex(str s)): a.typ = "<l>\<<pkg>.<s>\>";  
       case \iter-star(\lex(str s)): a.typ = "<l>\<<pkg>.<s>\>";
       case \iter-seps(\lex(str s), _): a.typ = "<l>\<<pkg>.<s>\>";
       case \iter-star-seps(\lex(str s), _): a.typ = "<l>\<<pkg>.<s>\>";
       case \parameterized-sort(str s, [Symbol _:str _(str z)]): a.typ = "<pkg>.<s>_<z>";
       case \parameterized-lex(str s, [Symbol _:str _(str z)]): a.typ = "<pkg>.<s>_<z>";
       case \iter(\parameterized-sort(str s, [Symbol _:str _(str z)])): a.typ = "<l>\<<pkg>.<s>_<z>\>";  
       case \iter-star(\parameterized-sort(str s, [Symbol _:str _(str z)])): a.typ = "<l>\<<pkg>.<s>_<z>\>";
       case \iter-seps(\parameterized-sort(str s, [Symbol _:str _(str z)]), _): a.typ = "<l>\<<pkg>.<s>_<z>\>";
       case \iter-star-seps(\parameterized-sort(str s, [Symbol _:str _(str z)]), _): a.typ = "<l>\<<pkg>.<s>_<z>\>";
       case \iter(\parameterized-lex(str s, [Symbol _:str _(str z)])): a.typ = "<l>\<<pkg>.<s>_<z>\>";  
       case \iter-star(\parameterized-lex(str s, [Symbol _:str _(str z)])): a.typ = "<l>\<<pkg>.<s>_<z>\>";
       case \iter-seps(\parameterized-lex(str s, [Symbol _:str _(str z)]), _): a.typ = "<l>\<<pkg>.<s>_<z>\>";
       case \iter-star-seps(\parameterized-lex(str s, [Symbol _:str _(str z)]), _): a.typ = "<l>\<<pkg>.<s>_<z>\>";
       
     }
     if (a.isOptional) {
        a.typ = replaceAll(a.typ, "<pkg>.", "<pkg>.@org.checkerframework.checker.nullness.qual.Nullable ");
     }
     append a;   
   }
}
 
str signature(list[Arg] args) {
  if (args == []) {
     return "";
  }
  h = head(args);
  return (", <h.typ> <h.name>" | "<it>,  <t> <a>" | arg(t, a) <- tail(args) );
}

str actuals(list[Arg] args) {
  if (args == []) {
     return "";
  }
  h = head(args);
  return (", <h.name>" | "<it>, <a>" | arg(_, a) <- tail(args) );
}

str cloneActuals(list[Arg] args) {
  if (args == []) {
     return "";
  }
  h = head(args);
  return (", clone(<h.name>)" | "<it>, clone(<a>)" | arg(_, a) <- tail(args) );
}

public str construct(Sig sig) {
  return "public <sig.name>(ISourceLocation src, IConstructor node <signature(sig.args)>) {
         '  super(src, node);
         '  <for (arg(_, name) <- sig.args) {>
         '  this.<name> = <name>;<}>
         '}";
}

private void loggedWriteFile(loc file, str src, str licenseHeader) {
  println("Writing <file>");
  writeFile(file, "<licenseHeader>
                  '<src>");
}
