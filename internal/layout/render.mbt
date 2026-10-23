///|
/// Joins tokens into one line with single spaces, gluing parentheses, commas
/// and semicolons to their neighbours: `count(*)`, `f(a, b);`.
///
/// Builtin function and type names are lowercased here, the one place shared
/// by emitting and measuring, so river widths agree with the emitted text.
pub fn render_tokens(toks : ArrayView[@lexer.Token]) -> String {
  let buf = StringBuilder()
  for i, t in toks {
    if i > 0 {
      let glued = match (toks[i - 1], t) {
        (LParen, _) | (Ident(_), LParen) | (_, RParen | Comma | Semicolon) =>
          true
        _ => false
      }
      if !glued {
        buf.write_char(' ')
      }
    }
    match t {
      Ident(w) =>
        buf.write_string(
          normalize_ident(w, followed_by_lparen=toks.get(i + 1) is Some(LParen)),
        )
      _ => buf.write_string(t.to_string())
    }
  }
  buf.to_string()
}
