///|
/// Raised by every parser when a statement falls outside the supported
/// grammar; `parse` turns it into a `Passthrough`.
priv suberror Unsupported

///|
/// Splits at depth-0 semicolons, each chunk keeping its semicolon. A trailing
/// run with no semicolon, such as a final comment, forms its own chunk.
fn split_statements(
  toks : ArrayView[@lexer.Spanned],
) -> Array[ArrayView[@lexer.Spanned]] {
  let chunks = []
  let mut depth = 0
  let mut start = 0
  for i, { token, .. } in toks {
    match token {
      Semicolon if depth == 0 => {
        chunks.push(toks[start:i + 1])
        start = i + 1
      }
      LParen => depth += 1
      RParen => depth = if depth > 0 { depth - 1 } else { 0 }
      _ => ()
    }
  }
  if start < toks.length() {
    chunks.push(toks[start:])
  }
  chunks
}

///|
/// Splits at depth-0 commas. An empty input yields one empty piece.
fn split_commas(
  toks : ArrayView[@lexer.Token],
) -> Array[ArrayView[@lexer.Token]] {
  let pieces = []
  let mut depth = 0
  let mut start = 0
  for i, token in toks {
    match token {
      Comma if depth == 0 => {
        pieces.push(toks[start:i])
        start = i + 1
      }
      LParen => depth += 1
      RParen => depth -= 1
      _ => ()
    }
  }
  pieces.push(toks[start:])
  pieces
}

///|
fn strip_semicolon(
  toks : ArrayView[@lexer.Token],
) -> (ArrayView[@lexer.Token], Bool) {
  match toks {
    [.. rest, Semicolon] => (rest, true)
    _ => (toks, false)
  }
}

///|
fn take_paren_group(
  toks : ArrayView[@lexer.Token],
) -> (ArrayView[@lexer.Token], ArrayView[@lexer.Token]) raise Unsupported {
  guard toks is [LParen, ..] else { raise Unsupported }
  let mut depth = 0
  for i in 1..<toks.length() {
    match toks[i] {
      RParen if depth == 0 => return (toks[1:i], toks[i + 1:])
      LParen => depth += 1
      RParen => depth -= 1
      _ => ()
    }
  }
  raise Unsupported
}

///|
fn find_top_level(
  toks : ArrayView[@lexer.Token],
  pred : (@lexer.Token) -> Bool,
) -> Int32? {
  let mut depth = 0
  for i, token in toks {
    match token {
      LParen => depth += 1
      RParen => depth -= 1
      t if depth == 0 && pred(t) => return Some(i)
      _ => ()
    }
  }
  None
}

///|
fn find_index(
  toks : ArrayView[@lexer.Token],
  pred : (@lexer.Token) -> Bool,
) -> Int32? {
  for i, token in toks {
    if pred(token) {
      return Some(i)
    }
  }
  None
}
