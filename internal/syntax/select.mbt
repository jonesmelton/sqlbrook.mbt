///|
/// Splits a `select`/`update`/`delete` into `(keyword, body)` segments at
/// depth-0 clause keywords, and in predicate context also at `and`/`or`,
/// except the `and` that pairs with a depth-0 `between`. Nothing splits
/// between `case` and its `end`.
fn to_segments(
  toks : ArrayView[@lexer.Token],
) -> Array[(String, ArrayView[@lexer.Token])] raise Unsupported {
  guard toks is [Keyword(first), ..] && is_clause_starter(first) else {
    raise Unsupported
  }
  let segments = []
  let mut kw = first
  let mut start = 1
  let mut depth = 0
  let mut after_between = false
  let mut cases = 0
  for i in 1..<toks.length() {
    match toks[i] {
      Keyword(k) if depth == 0 && cases == 0 && is_clause_starter(k) => {
        segments.push((kw, toks[start:i]))
        kw = k
        start = i + 1
        after_between = false
      }
      Keyword("case") if depth == 0 => cases += 1
      Keyword("when" | "then" | "else") if depth == 0 && cases > 0 => ()
      Keyword("end") if depth == 0 && cases > 0 => cases -= 1
      Keyword("and" | "or" as k) if depth == 0 && cases > 0 =>
        // An `and` inside a case may be a between's partner; clearing the flag
        // keeps it from swallowing a later depth-0 `and` after the case closes.
        after_between = after_between && k != "and"
      Keyword("and" | "or" as k) if depth == 0 && is_predicate_keyword(kw) =>
        if after_between && k == "and" {
          after_between = false
        } else {
          segments.push((kw, toks[start:i]))
          kw = k
          start = i + 1
          after_between = false
        }
      Keyword("between") if depth == 0 => after_between = true
      Keyword("as") if depth == 0 => ()
      Keyword(k) if depth == 0 && is_expr_keyword(k) => ()
      Keyword(_) if depth == 0 => raise Unsupported
      Comment(_) => raise Unsupported
      RParen if depth == 0 => raise Unsupported
      LParen => depth += 1
      RParen => depth -= 1
      _ => ()
    }
  }
  segments.push((kw, toks[start:]))
  segments
}

///|
/// The inside of an item that is exactly one paren group opening with
/// `select`. `foo(...)` and `(a + b) * c` stay blobs.
fn subquery_tokens(
  toks : ArrayView[@lexer.Token],
) -> ArrayView[@lexer.Token]? raise Unsupported {
  guard toks is [LParen, ..] else { return None }
  match take_paren_group(toks) {
    ([Keyword("select"), ..] as inner, []) => Some(inner)
    _ => None
  }
}

///|
/// Splits at depth-0 set operators into the operator and its arms, or `None`
/// when there is no set operator. Mixed operators are `Unsupported`: SQLite
/// groups them left-associatively, which a flat arm list cannot express.
fn split_setops(
  toks : ArrayView[@lexer.Token],
) -> (String, Array[ArrayView[@lexer.Token]])? raise Unsupported {
  let arms = []
  let mut op = None
  let mut depth = 0
  let mut start = 0
  for i, token in toks {
    match token {
      Keyword("union" | "union all" | "intersect" | "except" as k) if depth == 0 => {
        if op is Some(prev) && prev != k {
          raise Unsupported
        }
        op = Some(k)
        arms.push(toks[start:i])
        start = i + 1
      }
      LParen => depth += 1
      RParen => depth -= 1
      _ => ()
    }
  }
  guard op is Some(op) else { return None }
  arms.push(toks[start:])
  if arms.iter().any(arm => arm.is_empty()) {
    raise Unsupported
  }
  Some((op, arms))
}

///|
/// The comma-separated items of a clause body. With `aliases`, a trailing
/// `as <name>` becomes the item's `as_name`; any other depth-0 `as` is
/// unsupported.
fn to_items(
  body : ArrayView[@lexer.Token],
  aliases~ : Bool,
) -> Array[Item] raise Unsupported {
  let items = []
  for piece in split_commas(body) {
    let (expr, as_name) = match piece {
      [.. expr, Keyword("as"), Ident(name)] if aliases => (expr, Some(name))
      _ => (piece, None)
    }
    if expr.is_empty() ||
      find_top_level(expr, t => t is Keyword("as")) is Some(_) {
      raise Unsupported
    }
    let body = match subquery_tokens(expr) {
      Some(inner) => Sub(parse_select(inner))
      None => Blob(expr.to_owned())
    }
    items.push({ expr: body, as_name, })
  }
  items
}

///|
fn parse_select(toks : ArrayView[@lexer.Token]) -> Stmt raise Unsupported {
  let (toks, semi) = strip_semicolon(toks)
  match split_setops(toks) {
    Some((op, arms)) => Setop(op~, arms=arms.map(arm => parse_arm(arm)), semi~)
    None => parse_arm(toks, semi~)
  }
}

///|
fn parse_arm(
  toks : ArrayView[@lexer.Token],
  semi~ : Bool = false,
) -> Stmt raise Unsupported {
  let clauses = []
  for (kw, body) in to_segments(toks) {
    let items = if kw == "delete" && body.is_empty() {
      []
    } else if is_predicate_keyword(kw) {
      match to_items(body, aliases=false) {
        [item] => [item]
        _ => raise Unsupported
      }
    } else {
      to_items(body, aliases=kw == "select")
    }
    clauses.push({ kw, items, })
  }
  Dml(clauses~, semi~)
}
