///|
/// Input that is not lexable SQLite SQL.
///
/// `offset` is a UTF-8 byte offset into the source, so it points at the same
/// place a byte-oriented editor or tool would.
pub suberror LexError {
  UnexpectedByte(Byte, offset~ : Int32)
  PostgresCast(offset~ : Int32)
  PostgresDollarQuote(offset~ : Int32)
}

///|
pub impl Show for LexError with fn output(self, logger) {
  match self {
    UnexpectedByte(b, offset~) =>
      logger.write_string(
        "unexpected byte \{escape_byte(b)} at offset \{offset}",
      )
    PostgresCast(offset~) =>
      logger.write_string(
        "'::' is not SQLite syntax (PostgreSQL cast) at offset \{offset}; dialect is SQLite",
      )
    PostgresDollarQuote(offset~) =>
      logger.write_string(
        "'$$' is not SQLite syntax (PostgreSQL dollar-quote) at offset \{offset}; dialect is SQLite",
      )
  }
}

///|
pub extend LexError with Show::{to_string, output}

///|
/// A byte as a quoted character literal, in the notation of OCaml's `%C` so
/// messages match the reference implementation: printable ASCII as itself,
/// `\b \t \n \r` by name, and anything else as three decimal digits
/// (`'\001'`, `'\127'`).
fn escape_byte(b : Byte) -> String {
  let body = match b.to_int() {
    39 => "\\'"
    92 => "\\\\"
    8 => "\\b"
    9 => "\\t"
    10 => "\\n"
    13 => "\\r"
    n if n >= 32 && n < 127 => n.unsafe_to_char().to_string()
    n => "\\\{n.to_string().pad_start(3, '0')}"
  }
  "'\{body}'"
}

///|
/// The error for the character at `s[i]`. Only ASCII code units reach here:
/// every non-ASCII unit is an identifier character.
fn lex_error(s : String, i : Int32) -> LexError {
  let c = s[i]
  let offset = @text.utf8_width(s[:i])
  match (c, if i + 1 < s.length() { s[i + 1] } else { 0 }) {
    (':', ':') => PostgresCast(offset~)
    ('$', '$') => PostgresDollarQuote(offset~)
    _ => UnexpectedByte(c.to_byte(), offset~)
  }
}
