///|
priv struct SqlText {
  text : String
} derive(Debug)

///|
priv struct SoupText {
  text : String
} derive(Debug)

///|
priv struct ErrorCase {
  prefix : String
  bad : String
  suffix : String
} derive(Debug)

///|
fn below(rs : @quickcheck.RandomState, n : Int32) -> Int32 {
  rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn[T] pick(rs : @quickcheck.RandomState, items : ArrayView[T]) -> T {
  items[below(rs, items.length())]
}

///|
let words : Array[String] = [
  "select", "from", "where", "and", "or", "on", "as", "set", "insert", "into", "values",
  "with", "limit", "not", "null", "is", "in", "like", "join", "unique", "left", "right",
  "full", "outer", "inner", "cross", "order", "by", "group", "partition", "create",
  "table", "view", "index", "virtual", "if", "exists", "primary", "key", "foreign",
  "conflict", "union", "all", "without", "rowid", "ignore", "replace", "count", "integer",
]

///|
let name_chars : Array[String] = [
  "a", "b", "z", "_", "Q", "7", "0", "$", "é", "ß", "日", "😀",
]

///|
let body_chars : Array[String] = [
  "a", " ", "\n", "\t", "é", "日", "😀", "--", "(", ")", ";", ",", ":", "$",
  "@", "[", "\\", "x",
]

///|
let numbers : Array[String] = [
  "0", "42", "1.5", "1.", "0x1F", "0xabc", ".5", "1e5", "1.5E-3", "2e+10", "007",
]

///|
let placeholders : Array[String] = [
  ":name", "@x", "$y", "?", "?12", ":é", "@a_1",
]

///|
let operators : Array[String] = [
  "||", "<>", "!=", "<=", ">=", "==", "<<", ">>", "=", "<", ">", "+", "-", "*", "/",
  "%", "&", "|", "~", ".",
]

///|
let separators : Array[String] = ["", " ", "  ", "\t", "\n", "\r\n", " \n "]

///|
fn random_case(rs : @quickcheck.RandomState, word : String) -> String {
  let buf = StringBuilder()
  for c in word {
    buf.write_char(
      if below(rs, 2) == 0 {
        if c is ('a'..<='z') {
          (c.to_int() - 32).unsafe_to_char()
        } else {
          c
        }
      } else {
        c
      },
    )
  }
  buf.to_string()
}

///|
fn random_run(
  rs : @quickcheck.RandomState,
  pool : ArrayView[String],
  max_len : Int32,
  exclude? : String,
) -> String {
  let buf = StringBuilder()
  for _ in 0..<below(rs, max_len + 1) {
    let piece = pick(rs, pool)
    if exclude is Some(e) && piece.contains(e) {
      continue
    }
    buf.write_string(piece)
  }
  buf.to_string()
}

///|
fn random_name(rs : @quickcheck.RandomState) -> String {
  let start = pick(rs, ["a", "b", "z", "_", "Q", "é", "ß", "日", "😀"])
  start + random_run(rs, name_chars, 5)
}

///|
fn random_quoted(rs : @quickcheck.RandomState) -> String {
  match below(rs, 4) {
    0 =>
      "'\{random_run(rs, body_chars, 6, exclude="'").replace_all(old="--", new="-- ")}'" +
      (if below(rs, 3) == 0 { "''" } else { "" })
    1 => "\"\{random_run(rs, body_chars, 6, exclude="\"")}\""
    2 => "`\{random_run(rs, body_chars, 6, exclude="`")}`"
    _ => "[\{random_run(rs, body_chars, 6, exclude="]")}]"
  }
}

///|
fn random_piece(rs : @quickcheck.RandomState) -> String {
  match below(rs, 9) {
    0 | 1 => random_case(rs, pick(rs, words))
    2 | 3 => {
      let name = random_name(rs)
      if below(rs, 4) == 0 {
        name + "." + random_name(rs)
      } else {
        name
      }
    }
    4 => random_quoted(rs)
    5 => pick(rs, numbers)
    6 => pick(rs, placeholders)
    7 => pick(rs, operators)
    _ =>
      match below(rs, 5) {
        0 => "("
        1 => ")"
        2 => ","
        3 => ";"
        _ => "--" + random_run(rs, body_chars, 6, exclude="\n") + "\n"
      }
  }
}

///|
fn random_sql(rs : @quickcheck.RandomState, size : Int32) -> String {
  let buf = StringBuilder()
  for _ in 0..<(1 + below(rs, size.min(40) + 1)) {
    buf.write_string(random_piece(rs))
    buf.write_string(pick(rs, separators))
  }
  buf.to_string()
}

///|
impl @quickcheck.Arbitrary for SqlText with fn arbitrary(size, rs) {
  { text: random_sql(rs, size), }
}

///|
impl @quickcheck.Shrink for SqlText with fn shrink(_) {
  Iter::empty()
}

///|
let soup_chars : Array[String] = [
  "a", "Z", "_", "5", " ", "\n", "\t", "\r", ".", ",", ";", "(", ")", "=", "<", ">",
  "+", "*", "/", "%", "&", "|", "~", "-", "?", "é", "😀",
]

///|
impl @quickcheck.Arbitrary for SoupText with fn arbitrary(size, rs) {
  { text: random_run(rs, soup_chars, size.min(80)), }
}

///|
impl @quickcheck.Shrink for SoupText with fn shrink(_) {
  Iter::empty()
}

///|
impl @quickcheck.Arbitrary for ErrorCase with fn arbitrary(size, rs) {
  let prefix = random_sql(rs, size) + "\n"
  let suffix = " " + random_sql(rs, size)
  match below(rs, 3) {
    0 =>
      {
        prefix,
        bad: pick(rs, [
          "!", "#", "\\", "^", "{", "}", "\u{1}", "\u{7f}", "\u{8}", ":", "@", "$",
        ]),
        suffix,
      }
    1 => { prefix, bad: pick(rs, ["::", "$$"]), suffix, }
    _ => { prefix, bad: pick(rs, ["'", "\"", "`", "["]), suffix: "x y", }
  }
}

///|
impl @quickcheck.Shrink for ErrorCase with fn shrink(_) {
  Iter::empty()
}
