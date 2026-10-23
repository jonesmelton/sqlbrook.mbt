///|
pub using @lexer {type Token, type LexError, tokenize}

///|
/// A statement passed through unchanged. `kind` is its lowercased leading
/// keyword and `line` the 1-based line of its first token.
pub struct Skip {
  kind : String
  line : Int32
} derive(Debug, Eq)

///|
pub extend Skip with @debug.Debug::{to_repr}

///|
pub extend Skip with Eq::{not_equal, equal}

///|
/// The result of `format`. `skips` has one entry per passed-through
/// statement, in source order.
pub struct Formatted {
  output : String
  skips : Array[Skip]
} derive(Debug)

///|
pub extend Formatted with @debug.Debug::{to_repr}

///|
pub fn Formatted::had_passthrough(self : Formatted) -> Bool {
  !self.skips.is_empty()
}

///|
/// Formats SQLite source in the river style.
///
/// Statements are separated by one blank line and the output ends in a
/// newline, unless the input has no tokens, in which case it is empty. Each
/// statement's leading comments are kept above it. A statement outside the
/// supported grammar is copied verbatim and reported in `skips`; it is not an
/// error.
///
/// ```mbt check
/// test {
///   let r = @sqlbrook.format("select a, b from t;")
///   inspect(
///     r.output,
///     content=(
///       #|select a
///       #|     , b
///       #|  from t
///       #|       ;
///       #|
///     ),
///   )
///   assert_false(r.had_passthrough())
/// }
/// ```
///
/// # Errors
/// Raises `LexError` when the input has a character that starts no token, an
/// unterminated quote, or PostgreSQL-only syntax (`::`, `$$`).
pub fn format(input : String) -> Formatted raise LexError {
  let skips = []
  let statements = []
  // Skips arrive in source order, so lines are counted in one pass.
  let mut line = 1
  let mut counted = 0
  for { comments, stmt, } in @syntax.parse(input, @lexer.lex(input)) {
    let body = @layout.render_stmt(stmt)
    statements.push(
      if comments.is_empty() {
        body
      } else {
        comments.join("\n") + "\n" + body
      },
    )
    if stmt is Passthrough(kind~, offset~, ..) {
      for i in counted..<offset {
        if input[i] == '\n' {
          line += 1
        }
      }
      counted = offset
      skips.push({ kind, line, })
    }
  }
  let output = if statements.is_empty() {
    ""
  } else {
    statements.join("\n\n") + "\n"
  }
  { output, skips, }
}
