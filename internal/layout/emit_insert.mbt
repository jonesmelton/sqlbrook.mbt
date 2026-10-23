///|
/// `insert` puts `into <table>` on its first line; a multi-word verb takes a
/// line of its own with `into` aligned under it. Column, values and conflict
/// target lists are parenthesized blocks, and the semicolon closes the last
/// of them unless an `on conflict` or `returning` follows.
fn insert_lines(lines : Array[String], ins : @syntax.Insert, r : Int32) -> Unit {
  let { verb, table, cols, source, conflict, returning, semi, } = ins
  if verb == "insert" {
    lines.push(verb + " into " + render_tokens(table))
  } else {
    lines.push(verb)
    lines.push(pad(r - 4) + "into " + render_tokens(table))
  }
  if cols is Some(cols) {
    paren_block(lines, r, cols, pad(r - 1) + ")")
  }
  match source {
    // A `select` source has no paren to nest under, so it continues the
    // insert's river rather than indenting as a subquery would.
    Select(inner) => lines.append(stmt_lines(inner, river=r))
    Values(vals) => {
      lines.push(pad(r - 6) + "values")
      let close = match (conflict, returning, semi) {
        (Some(_), _, _) => pad(r - 1) + ")"
        (None, [_, ..], _) =>
          pad(r - 1) + ") returning " + render_tokens(returning)
        (None, [], true) => pad(r - 1) + ") ;"
        (None, [], false) => pad(r - 1) + ")"
      }
      paren_block(lines, r, vals, close)
    }
  }
  if conflict is Some({ target, assigns, }) {
    lines.push(pad(r - 11) + "on conflict")
    if target is Some(target) {
      paren_block(lines, r, target, pad(r - 1) + ")")
    }
    if assigns.is_empty() {
      lines.push(pad(r - 10) + "do nothing")
    } else {
      lines.push(pad(r - 9) + "do update")
    }
    for i, { lhs, rhs, } in assigns {
      let lead = if i == 0 { pad(r - 3) + "set " } else { pad(r - 1) + ", " }
      lines.push(lead + render_tokens(lhs))
      lines.push(pad(r + 1) + "= " + render_tokens(rhs))
    }
    if !returning.is_empty() {
      lines.push(pad(r - 9) + "returning " + render_tokens(returning))
    }
  }
  if semi && (!returning.is_empty() || conflict is Some(_)) {
    lines.push(pad(r + 1) + ";")
  }
}
