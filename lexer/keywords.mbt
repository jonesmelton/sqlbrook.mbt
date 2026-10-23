///|
/// Multi-word keywords, longest first so the first match is the longest.
let phrases : ReadOnlyArray[ReadOnlyArray[String]] = [
  ["insert", "or", "replace"],
  ["insert", "or", "ignore"],
  ["left", "outer", "join"],
  ["right", "outer", "join"],
  ["full", "outer", "join"],
  ["if", "not", "exists"],
  ["create", "unique", "index"],
  ["create", "virtual", "table"],
  ["create", "table"],
  ["create", "view"],
  ["order", "by"],
  ["group", "by"],
  ["partition", "by"],
  ["inner", "join"],
  ["left", "join"],
  ["cross", "join"],
  ["primary", "key"],
  ["foreign", "key"],
  ["on", "conflict"],
  ["union", "all"],
  ["create", "index"],
  ["without", "rowid"],
]

///|
/// Single-word keywords, given lowercased. Window-frame words (`rows`,
/// `range`, `preceding`) are deliberately not keywords; they lex as
/// identifiers, which is harmless because window functions pass through.
fn is_keyword(lw : String) -> Bool {
  match lw {
    "select"
    | "from"
    | "where"
    | "and"
    | "or"
    | "on"
    | "as"
    | "set"
    | "update"
    | "delete"
    | "insert"
    | "into"
    | "values"
    | "returning"
    | "with"
    | "limit"
    | "having"
    | "union"
    | "like"
    | "glob"
    | "not"
    | "null"
    | "is"
    | "in"
    | "between"
    | "exists"
    | "case"
    | "when"
    | "then"
    | "else"
    | "end"
    | "join"
    | "unique"
    | "default"
    | "references"
    | "filter"
    | "over"
    | "window"
    | "distinct"
    | "recursive"
    | "desc"
    | "asc"
    | "collate"
    | "all"
    | "intersect"
    | "except"
    | "using" => true
    _ => false
  }
}

///|
fn match_phrase(words : ArrayView[String?]) -> ReadOnlyArray[String]? {
  for phrase in phrases {
    guard phrase.length() <= words.length() else { continue }
    let matches = for k, word in phrase {
      guard words[k] is Some(w) && w == word else { break false }
    } nobreak {
      true
    }
    if matches {
      return Some(phrase)
    }
  }
  None
}

///|
fn assemble(raw : Array[Spanned]) -> Array[Spanned] {
  let words = raw.map(sp => {
    if sp.token is Ident(w) {
      Some(@text.ascii_lowercase(w))
    } else {
      None
    }
  })
  let out = []
  for i = 0; i < raw.length(); {
    let { token, start, end, } = raw[i]
    guard words[i] is Some(lw) else {
      out.push(raw[i])
      continue i + 1
    }
    match match_phrase(words[i:]) {
      Some(phrase) => {
        let last = i + phrase.length() - 1
        out.push({
          token: Keyword(phrase.iter().join(" ")),
          start,
          end: raw[last].end,
        })
        continue last + 1
      }
      None => {
        let token = if is_keyword(lw) { Keyword(lw) } else { token }
        out.push({ token, start, end, })
        continue i + 1
      }
    }
  }
  out
}
