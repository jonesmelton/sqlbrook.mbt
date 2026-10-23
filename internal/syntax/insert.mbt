///|
fn parse_insert(toks : ArrayView[@lexer.Token]) -> Stmt raise Unsupported {
  let (toks, semi) = strip_semicolon(toks)
  guard toks is [Keyword(verb), Keyword("into"), .. rest] &&
    is_insert_verb(verb) else {
    raise Unsupported
  }
  let table_end = match
    find_index(rest, t => t is (LParen | Keyword("values" | "select"))) {
    Some(i) if i > 0 => i
    _ => raise Unsupported
  }
  let table = rest[:table_end].to_owned()
  let rest = rest[table_end:]
  let (cols, rest) = match rest {
    [LParen, ..] => {
      let (cols, rest) = take_paren_group(rest)
      (Some(to_items(cols, aliases=false)), rest)
    }
    _ => (None, rest)
  }
  let (source, rest) = match rest {
    [Keyword("values"), .. rest] => {
      let (vals, rest) = take_paren_group(rest)
      // Multi-row values is a deliberate gap: it passes through.
      if rest is [Comma, ..] {
        raise Unsupported
      }
      (Values(to_items(vals, aliases=false)), rest)
    }
    [Keyword("select"), ..] => {
      let select = rest.to_owned()
      if semi {
        select.push(Semicolon)
      }
      (Select(parse_select(select)), [][:])
    }
    _ => raise Unsupported
  }
  let (conflict, rest) = match rest {
    [Keyword("on conflict"), ..] => {
      let (conflict, rest) = parse_conflict(rest)
      (Some(conflict), rest)
    }
    _ => (None, rest)
  }
  let returning = match rest {
    [Keyword("returning"), .. cols] if !cols.is_empty() => cols.to_owned()
    [] => []
    _ => raise Unsupported
  }
  Insert({ verb, table, cols, source, conflict, returning, semi, })
}

///|
fn parse_conflict(
  toks : ArrayView[@lexer.Token],
) -> (Conflict, ArrayView[@lexer.Token]) raise Unsupported {
  guard toks is [Keyword("on conflict"), .. rest] else { raise Unsupported }
  let (target, rest) = match rest {
    [LParen, ..] => {
      let (cols, rest) = take_paren_group(rest)
      (Some(to_items(cols, aliases=false)), rest)
    }
    _ => (None, rest)
  }
  match rest {
    [Ident("do"), Ident("nothing"), .. rest] => ({ target, assigns: [], }, rest)
    [Ident("do"), Keyword("update"), Keyword("set"), .. rest] => {
      let stop = find_index(rest, t => t is Keyword("returning")).unwrap_or(
        rest.length(),
      )
      let assigns = split_commas(rest[:stop]).map(parse_assign)
      ({ target, assigns, }, rest[stop:])
    }
    _ => raise Unsupported
  }
}

///|
fn parse_assign(toks : ArrayView[@lexer.Token]) -> Assign raise Unsupported {
  guard find_top_level(toks, t => t is Operator("=")) is Some(i) else {
    raise Unsupported
  }
  let lhs = toks[:i]
  let rhs = toks[i + 1:]
  if lhs.is_empty() || rhs.is_empty() {
    raise Unsupported
  }
  { lhs: lhs.to_owned(), rhs: rhs.to_owned(), }
}
