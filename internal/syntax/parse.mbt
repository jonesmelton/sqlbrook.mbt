///|
/// `with [recursive] <name> [(cols)] as (<select>)` followed by the
/// `select`, `update` or `insert` that uses it. Only a single CTE is
/// supported.
fn parse_cte(toks : ArrayView[@lexer.Token]) -> Stmt raise Unsupported {
  let (recursive, name, rest) = match toks {
    [Keyword("with"), Keyword("recursive"), Ident(name), .. rest] =>
      (true, name, rest)
    [Keyword("with"), Ident(name), .. rest] => (false, name, rest)
    _ => raise Unsupported
  }
  let (cols, rest) = match rest {
    [LParen, ..] => {
      let (cols, rest) = take_paren_group(rest)
      (to_items(cols, aliases=false), rest)
    }
    _ => ([], rest)
  }
  guard rest is [Keyword("as"), .. rest] else { raise Unsupported }
  let (body, rest) = take_paren_group(rest)
  guard body is [Keyword("select"), ..] else { raise Unsupported }
  let outer = match rest {
    [Keyword("select" | "update"), ..] => parse_select(rest)
    [Keyword(verb), ..] if is_insert_verb(verb) => parse_insert(rest)
    _ => raise Unsupported
  }
  Cte(recursive~, name~, cols~, body=parse_select(body), outer~)
}

///|
fn parse_statement(toks : ArrayView[@lexer.Token]) -> Stmt raise Unsupported {
  match toks {
    [Keyword("select" | "update" | "delete"), ..] => parse_select(toks)
    [Keyword(verb), ..] if is_insert_verb(verb) => parse_insert(toks)
    [Keyword("with"), ..] => parse_cte(toks)
    [Keyword("create table"), ..] => parse_create_table(toks)
    [Keyword("create index" | "create unique index"), ..] =>
      parse_create_index(toks)
    [Keyword("create virtual table"), ..] => parse_create_virtual_table(toks)
    [Keyword("create view"), ..] => parse_create_view(toks)
    _ => raise Unsupported
  }
}

///|
/// Parses the tokens of `src`, as returned by `@lexer.lex(src)`, into one
/// `Parsed` per statement.
///
/// Leading comments attach to the statement that follows them. A statement
/// outside the supported grammar becomes a `Passthrough` of its exact source
/// text, comments included, so parsing never fails.
pub fn parse(src : String, toks : Array[@lexer.Spanned]) -> Array[Parsed] {
  let parsed = []
  for chunk in split_statements(toks) {
    let comments = []
    let mut body_start = 0
    while body_start < chunk.length() &&
          chunk[body_start].token is Comment(text) {
      comments.push(text)
      body_start += 1
    }
    let body = chunk[body_start:].iter().map(spanned => spanned.token).collect()
    parsed.push({ comments, stmt: parse_statement(body), }) catch {
      Unsupported => {
        let start = chunk[0].start
        let kind = match body {
          [Keyword(k), ..] => k
          [token, ..] => token.to_string()
          [] => ""
        }
        let source = src[start:chunk[chunk.length() - 1].end].to_owned()
        let stmt = Passthrough(source~, kind~, offset=start)
        parsed.push({ comments: [], stmt, })
      }
    }
  }
  parsed
}
