///|
fn ddl_segment_end(toks : ArrayView[@lexer.Token]) -> Int32 {
  find_top_level(toks, t => t is Keyword(k) && is_ddl_break(k)).unwrap_or(
    toks.length(),
  )
}

///|
fn parse_ddl_item(toks : ArrayView[@lexer.Token]) -> DdlItem raise Unsupported {
  let (lead, rest) = match toks {
    [
      Ident(_)
      | Quoted(_)
      | Keyword("primary key" | "foreign key" | "unique") as lead,
      .. rest,
    ] => (lead, rest)
    _ => raise Unsupported
  }
  let head_end = ddl_segment_end(rest)
  let segments = []
  let mut after = rest[head_end:]
  while !after.is_empty() {
    guard after is [Keyword(k), .. tail] && is_ddl_break(k) else {
      raise Unsupported
    }
    let end = 1 + ddl_segment_end(tail)
    segments.push(after[:end].to_owned())
    after = after[end:]
  }
  { lead, head_rest: rest[:head_end].to_owned(), segments, }
}

///|
fn parse_create_table(toks : ArrayView[@lexer.Token]) -> Stmt raise Unsupported {
  let (toks, semi) = strip_semicolon(toks)
  let (header, rest) = match toks {
    [Keyword("create table"), Keyword("if not exists"), .. rest] =>
      (toks[:2], rest)
    [Keyword("create table"), .. rest] => (toks[:1], rest)
    _ => raise Unsupported
  }
  let name_end = match find_index(rest, t => t is LParen) {
    Some(i) if i > 0 => i
    _ => raise Unsupported
  }
  let (body, after) = take_paren_group(rest[name_end:])
  let without_rowid = match after {
    [Keyword("without rowid")] => true
    [] => false
    _ => raise Unsupported
  }
  CreateTable(
    header=header.to_owned(),
    name=rest[:name_end].to_owned(),
    defs=split_commas(body).map(parse_ddl_item),
    without_rowid~,
    semi~,
  )
}

///|
fn parse_create_index(toks : ArrayView[@lexer.Token]) -> Stmt raise Unsupported {
  let (toks, semi) = strip_semicolon(toks)
  guard toks
    is [Keyword("create index" | "create unique index" as verb), .. rest] else {
    raise Unsupported
  }
  let name_end = match find_index(rest, t => t is Keyword("on")) {
    Some(i) if i > 0 => i
    _ => raise Unsupported
  }
  let on = rest[name_end:]
  let (table, predicate) = match
    find_top_level(on, t => t is Keyword("where")) {
    Some(i) => (on[:i], on[i + 1:])
    None => (on, [][:])
  }
  CreateIndex(
    verb~,
    name=rest[:name_end].to_owned(),
    table=table.to_owned(),
    predicate=predicate.to_owned(),
    semi~,
  )
}

///|
fn parse_create_virtual_table(
  toks : ArrayView[@lexer.Token],
) -> Stmt raise Unsupported {
  let (toks, semi) = strip_semicolon(toks)
  guard toks is [Keyword("create virtual table" as verb), .. rest] else {
    raise Unsupported
  }
  let name_end = match find_index(rest, t => t is Keyword("using")) {
    Some(i) if i > 0 => i
    _ => raise Unsupported
  }
  CreateVirtualTable(
    verb~,
    name=rest[:name_end].to_owned(),
    module_args=rest[name_end:].to_owned(),
    semi~,
  )
}

///|
fn parse_create_view(toks : ArrayView[@lexer.Token]) -> Stmt raise Unsupported {
  guard find_top_level(toks, t => t is Keyword("as")) is Some(as_at) else {
    raise Unsupported
  }
  let header = toks[:as_at]
  let body = toks[as_at + 1:]
  guard header is [Keyword("create view"), _, ..] else { raise Unsupported }
  guard body is [Keyword("select"), ..] else { raise Unsupported }
  CreateView(header=header.to_owned(), body=parse_select(body))
}
