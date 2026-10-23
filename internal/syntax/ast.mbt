///|
pub enum ItemBody {
  Blob(Array[@lexer.Token])
  Sub(Stmt)
}

///|
pub struct Item {
  expr : ItemBody
  as_name : String?
}

///|
pub struct Clause {
  kw : String
  items : Array[Item]
}

///|
/// A column or constraint definition of `create table`. `lead` is the
/// right-aligned left-column token; `head_rest` follows it on the same line,
/// and each of `segments` gets its own continuation line.
pub struct DdlItem {
  lead : @lexer.Token
  head_rest : Array[@lexer.Token]
  segments : Array[Array[@lexer.Token]]
}

///|
pub struct Assign {
  lhs : Array[@lexer.Token]
  rhs : Array[@lexer.Token]
}

///|
/// An `on conflict` clause. Empty `assigns` means `do nothing`.
pub struct Conflict {
  target : Array[Item]?
  assigns : Array[Assign]
}

///|
pub enum Source {
  Values(Array[Item])
  Select(Stmt)
}

///|
/// `cols` is `None` when the column list is omitted.
pub struct Insert {
  verb : String
  table : Array[@lexer.Token]
  cols : Array[Item]?
  source : Source
  conflict : Conflict?
  returning : Array[@lexer.Token]
  semi : Bool
}

///|
pub enum Stmt {
  Dml(clauses~ : Array[Clause], semi~ : Bool)
  Insert(Insert)
  CreateTable(
    header~ : Array[@lexer.Token],
    name~ : Array[@lexer.Token],
    defs~ : Array[DdlItem],
    without_rowid~ : Bool,
    semi~ : Bool
  )
  /// `header` is `create view [if not exists] <name>`; `body` carries the
  /// semicolon.
  CreateView(header~ : Array[@lexer.Token], body~ : Stmt)
  /// `table` is `on <table> (cols)` kept whole; `predicate` is empty when
  /// there is no `where`.
  CreateIndex(
    verb~ : String,
    name~ : Array[@lexer.Token],
    table~ : Array[@lexer.Token],
    predicate~ : Array[@lexer.Token],
    semi~ : Bool
  )
  CreateVirtualTable(
    verb~ : String,
    name~ : Array[@lexer.Token],
    module_args~ : Array[@lexer.Token],
    semi~ : Bool
  )
  /// A single common table expression. `outer` is the statement that uses
  /// it and carries the semicolon.
  Cte(
    recursive~ : Bool,
    name~ : String,
    cols~ : Array[Item],
    body~ : Stmt,
    outer~ : Stmt
  )
  /// A chain of one set operator, flattened: two or more `arms`.
  Setop(op~ : String, arms~ : Array[Stmt], semi~ : Bool)
  /// A statement outside the supported grammar. `source` is its exact source
  /// slice, leading comments included; `kind` its lowercased leading keyword;
  /// `offset` the `String` index of its first token.
  Passthrough(source~ : String, kind~ : String, offset~ : Int32)
}

///|
pub struct Parsed {
  comments : Array[String]
  stmt : Stmt
}
