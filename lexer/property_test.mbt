///|
fn is_space(c : Char) -> Bool {
  c is (' ' | '\t' | '\r' | '\n')
}

///|
fn collapse_space(s : StringView) -> String {
  let buf = StringBuilder()
  let mut in_space = false
  for c in s {
    if is_space(c) {
      if !in_space {
        buf.write_char(' ')
      }
      in_space = true
    } else {
      buf.write_char(c)
      in_space = false
    }
  }
  buf.to_string()
}

///|
fn only_space(s : StringView) -> Bool {
  s.iter().all(is_space)
}

///|
fn spans_cover_source(source : String) -> Bool raise @lexer.LexError {
  let mut pos = 0
  for sp in @lexer.lex(source) {
    let slice = source[sp.start:sp.end]
    let text_ok = match sp.token {
      Keyword(kw) => @text.ascii_lowercase(collapse_space(slice)) == kw
      t => Show::to_string(t) == slice.to_owned()
    }
    if sp.start < pos ||
      sp.end <= sp.start ||
      !only_space(source[pos:sp.start]) ||
      !text_ok {
      return false
    }
    pos = sp.end
  }
  only_space(source[pos:])
}

///|
test "property: spans are ordered, tile the source up to whitespace, and match token text" {
  @quickcheck.check((t : SqlText) => spans_cover_source(t.text), count=500)
}

///|
fn flat_text(toks : Array[@lexer.Token]) -> String {
  let buf = StringBuilder()
  for t in toks {
    buf.write_string(Show::to_string(t))
    buf.write_char(if t is Comment(_) { '\n' } else { ' ' })
  }
  buf.to_string()
}

///|
test "property: re-lexing the flat token text reproduces the tokens" {
  @quickcheck.check(
    (t : SqlText) => {
      let toks = @lexer.tokenize(t.text)
      @lexer.tokenize(flat_text(toks)) == toks
    },
    count=500,
  )
}

///|
test "property: generated SQL never raises" {
  @quickcheck.check(
    (t : SqlText) => {
      ignore(@lexer.tokenize(t.text))
      true
    },
    count=500,
  )
}

///|
test "property: characters that each form a token alone never raise" {
  @quickcheck.check(
    (t : SoupText) => {
      ignore(@lexer.tokenize(t.text))
      true
    },
    count=500,
  )
}

///|
test "property: lex errors carry the UTF-8 byte offset of the offending character" {
  @quickcheck.check(
    (e : ErrorCase) => {
      let source = e.prefix + e.bad + e.suffix
      let offset = @utf8.encode(e.prefix).length()
      try @lexer.tokenize(source) catch {
        PostgresCast(offset=o) => e.bad == "::" && o == offset
        PostgresDollarQuote(offset=o) => e.bad == "$$" && o == offset
        UnexpectedByte(b, offset=o) =>
          b.to_int() == e.bad[0].to_int() &&
          o == offset &&
          e.bad != "::" &&
          e.bad != "$$"
      } noraise {
        _ => false
      }
    },
    count=500,
  )
}
