///|
fn lex_raw(s : String) -> Array[Spanned] raise LexError {
  let out = []
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = s[i]
    let next = if i + 1 < n { s[i + 1] } else { 0 }
    let (token, end) : (Token, Int32) = match c {
      ' ' | '\t' | '\r' | '\n' => {
        i += 1
        continue
      }
      '-' if next == '-' => {
        let e = scan_while(s, i, c => c != '\n')
        (Comment(s[i:e].to_owned()), e)
      }
      '\'' | '"' | '`' =>
        match scan_quoted(s, i, c) {
          Some(e) => (Quoted(s[i:e].to_owned()), e)
          None => raise lex_error(s, i)
        }
      '[' =>
        match scan_while(s, i + 1, c => c != ']') {
          e if e < n => (Quoted(s[i:e + 1].to_owned()), e + 1)
          _ => raise lex_error(s, i)
        }
      '0'..<='9' | '.' if c != '.' || is_digit(next) => {
        let e = scan_number(s, i)
        (Number(s[i:e].to_owned()), e)
      }
      ':' | '@' | '$' if is_ident_start(next) => {
        let e = scan_while(s, i + 2, is_ident_char)
        (Placeholder(s[i:e].to_owned()), e)
      }
      '?' => {
        let e = scan_while(s, i + 1, is_digit)
        (Placeholder(s[i:e].to_owned()), e)
      }
      'a'..<='z' | 'A'..<='Z' | '_' | '\u0080'..<='\uffff' => {
        let e = scan_word(s, i)
        (Ident(s[i:e].to_owned()), e)
      }
      '(' => (LParen, i + 1)
      ')' => (RParen, i + 1)
      ',' => (Comma, i + 1)
      ';' => (Semicolon, i + 1)
      '|' | '<' | '>' | '=' | '!' if is_two_char_op(c, next) =>
        (Operator(s[i:i + 2].to_owned()), i + 2)
      '=' | '<' | '>' | '+' | '-' | '*' | '/' | '%' | '&' | '|' | '~' | '.' =>
        (Operator(s[i:i + 1].to_owned()), i + 1)
      _ => raise lex_error(s, i)
    }
    out.push({ token, start: i, end, })
    i = end
  }
  out
}

///|
/// Splits SQLite source into tokens with their source ranges, dropping
/// whitespace.
///
/// ```mbt check
/// test {
///   let spans = @lexer.lex("SELECT a  FROM t")
///   inspect(
///     spans.map(sp => "\{sp.token}@\{sp.start}-\{sp.end}").join(" "),
///     content="select@0-6 a@7-8 from@10-14 t@15-16",
///   )
/// }
/// ```
///
/// # Errors
/// Raises `LexError` on a character that starts no token, on an unterminated
/// quote, or on PostgreSQL-only syntax (`::`, `$$`).
pub fn lex(source : String) -> Array[Spanned] raise LexError {
  assemble(lex_raw(source))
}

///|
/// Splits SQLite source into tokens, dropping whitespace. Keywords come back
/// lowercased; everything else keeps its source spelling.
///
/// ```mbt check
/// test {
///   debug_inspect(
///     @lexer.tokenize("Order  By x"),
///     content=(
///       #|[Keyword("order by"), Ident("x")]
///     ),
///   )
/// }
/// ```
///
/// # Errors
/// Raises `LexError` under the same conditions as `lex`.
pub fn tokenize(source : String) -> Array[Token] raise LexError {
  lex(source).map(spanned => spanned.token)
}
