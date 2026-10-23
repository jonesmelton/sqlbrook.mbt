///|
/// A SQLite token. Whitespace is not a token.
///
/// `Keyword` payloads are lowercased and may be multi-word phrases such as
/// `order by`, with the words joined by one space. Every other payload is the
/// exact source text, so `to_string` reproduces the token as written.
pub(all) enum Token {
  Keyword(String)
  Ident(String)
  /// A string literal or quoted identifier, delimiters included: `'..'`,
  /// `".."`, `` `..` ``, `[..]`.
  Quoted(String)
  Number(String)
  Operator(String)
  Placeholder(String)
  LParen
  RParen
  Comma
  Semicolon
  /// A `--` line comment, excluding the trailing newline.
  Comment(String)
} derive(Eq, Debug)

///|
pub impl Show for Token with fn output(self, logger) {
  logger.write_string(
    match self {
      Keyword(s)
      | Ident(s)
      | Quoted(s)
      | Number(s)
      | Operator(s)
      | Placeholder(s)
      | Comment(s) => s
      LParen => "("
      RParen => ")"
      Comma => ","
      Semicolon => ";"
    },
  )
}

///|
pub extend Token with @debug.Debug::{to_repr}

///|
pub extend Token with Eq::{not_equal, equal}

///|
pub extend Token with Show::{to_string, output}

///|
/// A token and the source range `[start, end)` it was lexed from.
///
/// Offsets are `String` indices (UTF-16 code units). A multi-word keyword
/// spans from its first word to its last, whitespace between them included.
pub struct Spanned {
  token : Token
  start : Int32
  end : Int32
} derive(Eq, Debug)

///|
pub extend Spanned with @debug.Debug::{to_repr}

///|
pub extend Spanned with Eq::{not_equal, equal}
