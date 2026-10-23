///|
/// Lowercases ASCII letters and leaves every other code unit untouched.
///
/// SQL keywords and builtin names are ASCII, so this is the only case folding
/// the formatter needs; non-ASCII identifiers keep their spelling.
pub fn ascii_lowercase(s : StringView) -> String {
  let buf = StringBuilder()
  for c in s {
    buf.write_char(
      if c is ('A'..<='Z') {
        (c.to_int() + 32).unsafe_to_char()
      } else {
        c
      },
    )
  }
  buf.to_string()
}
