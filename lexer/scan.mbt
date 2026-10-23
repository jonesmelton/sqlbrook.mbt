///|
fn is_digit(c : UInt16) -> Bool {
  c is ('0'..<='9')
}

///|
fn is_hex(c : UInt16) -> Bool {
  c is ('0'..<='9' | 'a'..<='f' | 'A'..<='F')
}

///|
fn is_ident_start(c : UInt16) -> Bool {
  c is ('a'..<='z' | 'A'..<='Z' | '_') || c >= 0x80
}

///|
fn is_ident_char(c : UInt16) -> Bool {
  is_ident_start(c) || is_digit(c) || c == '$'
}

///|
fn is_two_char_op(a : UInt16, b : UInt16) -> Bool {
  match (a, b) {
    ('|', '|') | ('<', '>' | '=' | '<') | ('>', '=' | '>') | ('!' | '=', '=') =>
      true
    _ => false
  }
}

///|
fn scan_while(s : String, from : Int32, pred : (UInt16) -> Bool) -> Int32 {
  let mut j = from
  while j < s.length() && pred(s[j]) {
    j += 1
  }
  j
}

///|
fn has_at(s : String, i : Int32, pred : (UInt16) -> Bool) -> Bool {
  i < s.length() && pred(s[i])
}

///|
/// The end of the quoted run opening at `from`, where a doubled `quote` is an
/// escaped quote. `None` when the run is unterminated.
fn scan_quoted(s : String, from : Int32, quote : UInt16) -> Int32? {
  let n = s.length()
  let mut best = None
  let mut j = from + 1
  while j < n {
    guard s[j] == quote else {
      j += 1
      continue
    }
    best = Some(j + 1)
    if j + 1 < n && s[j + 1] == quote {
      j += 2
    } else {
      break
    }
  }
  best
}

///|
/// The end of the numeric literal at `from`: hex (`0x1F`), decimal with an
/// optional fraction (`1.5`, `1.`, `.5`) and an optional exponent. An exponent
/// marker without digits is not part of the number, so `1e` lexes as `1`
/// then `e`.
fn scan_number(s : String, from : Int32) -> Int32 {
  if s[from] == '0' && has_at(s, from + 1, c => c == 'x') {
    let k = scan_while(s, from + 2, is_hex)
    if k > from + 2 {
      return k
    }
  }
  let mut j = if s[from] == '.' {
    scan_while(s, from + 1, is_digit)
  } else {
    let int_end = scan_while(s, from, is_digit)
    if has_at(s, int_end, c => c == '.') {
      scan_while(s, int_end + 1, is_digit)
    } else {
      int_end
    }
  }
  if has_at(s, j, c => c is ('e' | 'E')) {
    let sign_end = if has_at(s, j + 1, c => c is ('+' | '-')) {
      j + 2
    } else {
      j + 1
    }
    let digits_end = scan_while(s, sign_end, is_digit)
    if digits_end > sign_end {
      j = digits_end
    }
  }
  j
}

///|
fn scan_word(s : String, from : Int32) -> Int32 {
  let mut j = scan_while(s, from + 1, is_ident_char)
  while has_at(s, j, c => c == '.') && has_at(s, j + 1, is_ident_start) {
    j = scan_while(s, j + 2, is_ident_char)
  }
  j
}
