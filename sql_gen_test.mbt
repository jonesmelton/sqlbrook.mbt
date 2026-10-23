///|
struct Gen {
  rs : @quickcheck.RandomState
  out : Array[String]
}

///|
fn Gen::new(rs : @quickcheck.RandomState) -> Gen {
  { rs, out: [], }
}

///|
fn Gen::below(self : Gen, n : Int32) -> Int32 {
  self.rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn Gen::chance(self : Gen, n : Int32) -> Bool {
  self.below(n) == 0
}

///|
fn[T] Gen::pick(self : Gen, items : ArrayView[T]) -> T {
  items[self.below(items.length())]
}

///|
fn Gen::raw(self : Gen, piece : String) -> Unit {
  self.out.push(piece)
}

///|
let ws_inner : Array[String] = [" ", "  ", "\n", "\t", "\r\n", " \n  "]

///|
fn Gen::kw(self : Gen, phrase : String) -> Unit {
  let buf = StringBuilder()
  for i, word in phrase.split(" ").collect() {
    if i > 0 {
      buf.write_string(self.pick(ws_inner))
    }
    for c in word {
      buf.write_char(
        if c is ('a'..<='z') && self.chance(2) {
          (c.to_int() - 32).unsafe_to_char()
        } else {
          c
        },
      )
    }
  }
  self.raw(buf.to_string())
}

///|
let names : Array[String] = [
  "a", "b", "c", "id", "slug", "tree", "x1", "col_2", "é", "日本語", "naïve",
  "ünï", "😀x", "t_é", "users", "items", "_p",
]

///|
let quoted_names : Array[String] = [
  "\"a b\"", "`weird;name`", "[col é]", "\"日本\"", "\"it\"\"s\"", "`x--y`",
]

///|
fn Gen::name(self : Gen) -> String {
  if self.chance(8) {
    self.pick(quoted_names)
  } else {
    self.pick(names)
  }
}

///|
fn Gen::name_piece(self : Gen) -> Unit {
  self.raw(self.name())
}

///|
fn Gen::qualified(self : Gen) -> Unit {
  self.raw(
    if self.chance(3) {
      self.name() + "." + self.name()
    } else {
      self.name()
    },
  )
}

///|
let literals : Array[String] = [
  "0", "42", "1.5", "0x1F", ".5", "1e5", "'x'", "''", "'it''s'", "'日本 é'", "'a -- b'",
  "'x;y'", "'(unbalanced'", "?", "?12", ":name", "@x", "$y", "null",
]

///|
let binops : Array[String] = [
  "=", "<>", "!=", "<", "<=", ">", ">=", "+", "-", "*", "/", "||", "%", "==",
]

///|
fn Gen::atom(self : Gen) -> Unit {
  if self.chance(2) {
    self.qualified()
  } else {
    self.raw(self.pick(literals))
  }
}

///|
fn Gen::expr_list(self : Gen, depth : Int32, max : Int32) -> Unit {
  for i in 0..<(1 + self.below(max)) {
    if i > 0 {
      self.raw(",")
    }
    self.expr(depth)
  }
}

///|
fn Gen::expr(self : Gen, depth : Int32) -> Unit {
  if depth <= 0 {
    self.atom()
    return
  }
  match self.below(12) {
    0 | 1 | 2 => self.atom()
    3 | 4 => {
      self.expr(depth - 1)
      self.raw(self.pick(binops))
      self.expr(depth - 1)
    }
    5 => {
      self.name_piece()
      self.raw("(")
      if self.chance(6) {
        self.raw("*")
      } else {
        self.expr_list(depth - 1, 3)
      }
      self.raw(")")
    }
    6 => {
      self.raw("(")
      self.expr(depth - 1)
      self.raw(")")
    }
    7 => {
      self.expr(depth - 1)
      self.kw(if self.chance(2) { "is null" } else { "is not null" })
    }
    8 => {
      self.expr(depth - 1)
      self.kw(self.pick(["like", "glob", "not like"]))
      self.raw(self.pick(["?", "'%x%'", ":pat"]))
    }
    9 => {
      self.expr(depth - 1)
      self.kw(if self.chance(3) { "not in" } else { "in" })
      self.raw("(")
      self.expr_list(depth - 1, 3)
      self.raw(")")
    }
    10 =>
      if depth >= 2 {
        self.raw("(")
        self.select(depth - 2)
        self.raw(")")
      } else {
        self.atom()
      }
    _ => {
      self.kw("not")
      self.expr(depth - 1)
    }
  }
}

///|
fn Gen::cond(self : Gen, depth : Int32) -> Unit {
  for i in 0..<(1 + self.below(3)) {
    if i > 0 {
      self.kw(if self.chance(3) { "or" } else { "and" })
    }
    match self.below(6) {
      0 => {
        self.kw("exists")
        self.raw("(")
        self.select(0)
        self.raw(")")
      }
      1 => {
        self.qualified()
        self.kw("is null")
      }
      _ => {
        self.qualified()
        self.raw(self.pick(["=", "<>", "<", ">=", "!="]))
        self.expr(depth)
      }
    }
  }
}

///|
fn Gen::table_ref(self : Gen, depth : Int32) -> Unit {
  if depth >= 1 && self.chance(5) {
    self.raw("(")
    self.select(depth - 1)
    self.raw(")")
    self.name_piece()
  } else {
    self.name_piece()
    if self.chance(5) {
      self.name_piece()
    }
  }
}

///|
let join_kinds : Array[String] = [
  "join", "inner join", "left join", "cross join", "left outer join", "right outer join",
  "full outer join",
]

///|
fn Gen::select_item(self : Gen, depth : Int32) -> Unit {
  if self.chance(8) {
    self.raw("*")
    return
  }
  self.expr(depth)
  if self.chance(4) {
    self.name_piece()
  } else if self.chance(8) {
    self.kw("as")
    self.raw(self.pick(names))
  }
}

///|
fn Gen::select_core(self : Gen, depth : Int32) -> Unit {
  self.kw("select")
  if self.chance(6) {
    self.kw("distinct")
  }
  for i in 0..<(1 + self.below(4)) {
    if i > 0 {
      self.raw(",")
    }
    self.select_item(depth)
  }
  self.kw("from")
  self.table_ref(depth)
  for _ in 0..<self.below(3) {
    self.kw(self.pick(join_kinds))
    self.table_ref(depth)
    self.kw("on")
    self.cond(0)
  }
  if self.chance(2) {
    self.kw("where")
    self.cond(depth)
  }
  if self.chance(5) {
    self.kw("group by")
    self.expr_list(0, 3)
    if self.chance(3) {
      self.kw("having")
      self.cond(0)
    }
  }
  if self.chance(3) {
    self.kw("order by")
    for i in 0..<(1 + self.below(3)) {
      if i > 0 {
        self.raw(",")
      }
      self.qualified()
      if self.chance(2) {
        self.kw(if self.chance(2) { "desc" } else { "asc" })
      }
    }
  }
  if self.chance(4) {
    self.kw("limit")
    self.raw(self.pick(["1", "10", "?", ":n"]))
  }
}

///|
fn Gen::select(self : Gen, depth : Int32) -> Unit {
  self.select_core(depth)
  if depth >= 1 && self.chance(6) {
    self.kw(self.pick(["union", "union all", "intersect", "except"]))
    self.select_core(depth - 1)
  }
}

///|
fn Gen::col_list(self : Gen) -> Unit {
  self.raw("(")
  for i in 0..<(1 + self.below(3)) {
    if i > 0 {
      self.raw(",")
    }
    self.name_piece()
  }
  self.raw(")")
}

///|
fn Gen::returning(self : Gen) -> Unit {
  if self.chance(4) {
    self.kw("returning")
    if self.chance(4) {
      self.raw("*")
    } else {
      for i in 0..<(1 + self.below(3)) {
        if i > 0 {
          self.raw(",")
        }
        self.name_piece()
      }
    }
  }
}

///|
fn Gen::assigns(self : Gen) -> Unit {
  for i in 0..<(1 + self.below(3)) {
    if i > 0 {
      self.raw(",")
    }
    self.name_piece()
    self.raw("=")
    self.expr(1)
  }
}

///|
fn Gen::insert(self : Gen) -> Unit {
  self.kw(
    self.pick(["insert into", "insert or replace into", "insert or ignore into"]),
  )
  self.name_piece()
  if self.chance(2) {
    self.col_list()
  }
  if self.chance(4) {
    self.select(1)
    self.returning()
    return
  } else {
    self.kw("values")
    self.raw("(")
    self.expr_list(1, 4)
    self.raw(")")
  }
  if self.chance(3) {
    self.kw("on conflict")
    if self.chance(2) {
      self.col_list()
    }
    if self.chance(2) {
      self.raw("do")
      self.raw("nothing")
    } else {
      self.raw("do")
      self.kw("update set")
      self.assigns()
    }
  }
  self.returning()
}

///|
fn Gen::update(self : Gen) -> Unit {
  self.kw("update")
  self.name_piece()
  self.kw("set")
  self.assigns()
  if self.chance(4) {
    self.kw("from")
    self.table_ref(0)
  }
  if self.chance(4) {
    self.kw("where")
    self.cond(1)
  }
  self.returning()
}

///|
fn Gen::delete(self : Gen) -> Unit {
  self.kw("delete")
  self.kw("from")
  self.name_piece()
  if self.chance(3) {
    self.kw("where")
    self.cond(1)
  }
  self.returning()
}

///|
fn Gen::cte(self : Gen) -> Unit {
  self.kw("with")
  if self.chance(4) {
    self.kw("recursive")
  }
  for _ in 0..<1 {
    self.raw(self.pick(names))
    if self.chance(3) {
      self.col_list()
    }
    self.kw("as")
    self.raw("(")
    self.select(1)
    self.raw(")")
  }
  self.select(1)
}

///|
let col_types : Array[String] = ["integer", "text", "blob", "real", "numeric"]

///|
fn Gen::create_table(self : Gen) -> Unit {
  self.kw(
    if self.chance(4) {
      "create table if not exists"
    } else {
      "create table"
    },
  )
  self.name_piece()
  self.raw("(")
  for i in 0..<(1 + self.below(4)) {
    if i > 0 {
      self.raw(",")
    }
    self.name_piece()
    self.raw(self.pick(col_types))
    for _ in 0..<self.below(3) {
      match self.below(5) {
        0 => self.kw("primary key")
        1 => self.kw("not null")
        2 => self.kw("unique")
        3 => {
          self.kw("default")
          self.raw(self.pick(["0", "''", "null"]))
        }
        _ => {
          self.kw("references")
          self.name_piece()
          self.col_list()
        }
      }
    }
  }
  if self.chance(4) {
    self.raw(",")
    self.kw("primary key")
    self.col_list()
  }
  self.raw(")")
  if self.chance(4) {
    self.kw("without rowid")
  }
}

///|
fn Gen::create_other(self : Gen) -> Unit {
  match self.below(3) {
    0 => {
      self.kw(
        if self.chance(2) {
          "create view"
        } else {
          "create view if not exists"
        },
      )
      self.name_piece()
      self.kw("as")
      self.select(1)
    }
    1 => {
      self.kw(self.pick(["create index", "create unique index"]))
      self.name_piece()
      self.kw("on")
      self.name_piece()
      self.col_list()
      if self.chance(3) {
        self.kw("where")
        self.cond(0)
      }
    }
    _ => {
      self.kw("create virtual table")
      self.name_piece()
      self.kw("using")
      self.raw(self.pick(["fts5", "rtree"]))
      self.col_list()
    }
  }
}

///|
let unsupported_stmts : Array[Array[String]] = [
  ["drop", "table", "t"],
  ["pragma", "foreign_keys", "=", "on"],
  ["alter", "table", "t", "add", "column", "c", "text"],
  ["begin"],
  ["commit"],
  ["vacuum"],
  ["insert into", "t", "values", "(", "1", ")", ",", "(", "2", ")"],
  [
    "select", "row_number", "(", ")", "over", "(", "partition", "by", "a", ")", "from",
    "t",
  ],
  ["replace into", "t", "values", "(", "1", ")"],
  ["explain", "select", "a", "from", "t"],
  ["attach", "database", "'x'", "as", "y"],
]

///|
fn Gen::unsupported(self : Gen) -> Unit {
  let words = self.pick(unsupported_stmts)
  for w in words {
    match w {
      "("
      | ")"
      | ","
      | "="
      | ";"
      | "t"
      | "a"
      | "b"
      | "c"
      | "x"
      | "tr"
      | "1"
      | "2"
      | "foreign_keys"
      | "on"
      | "text"
      | "'x'"
      | "y" => self.raw(w)
      _ => self.kw(w)
    }
  }
}

///|
fn Gen::comment(self : Gen) -> Unit {
  self.raw(
    "--" +
    self.pick([
      "", " note", " select a from t;", " 日本 é", "-- nested", " 'quote", " ; ; ;",
    ]),
  )
}

///|
fn Gen::supported(self : Gen) -> Unit {
  match self.below(9) {
    0 | 1 | 2 => self.select(2)
    3 => self.insert()
    4 => self.update()
    5 => self.delete()
    6 => self.cte()
    7 => self.create_table()
    _ => self.create_other()
  }
}

///|
fn Gen::join_pieces(self : Gen, pieces : Array[String]) -> String {
  let buf = StringBuilder()
  for i, piece in pieces {
    if i > 0 {
      let prev = pieces[i - 1]
      let is_punct = fn(s : String) { s is ("(" | ")" | "," | ";") }
      let sep = if prev.has_prefix("--") {
        self.pick(["\n", "\n\n", "\r\n", "\n    "])
      } else if is_punct(prev) || is_punct(piece) {
        self.pick(["", "", " ", "\n", "  ", "\t"])
      } else {
        self.pick(ws_inner)
      }
      buf.write_string(sep)
    }
    buf.write_string(piece)
  }
  buf.to_string()
}

///|
fn Gen::statement(self : Gen) -> (String, Bool) {
  self.out.clear()
  for _ in 0..<(if self.chance(4) { 1 + self.below(2) } else { 0 }) {
    self.comment()
  }
  let skipped = self.chance(5)
  if skipped {
    self.unsupported()
  } else {
    self.supported()
  }
  (self.join_pieces(self.out), skipped)
}

///|
struct Part {
  lead : String
  text : String
  semi_ws : String
  has_semi : Bool
  skipped : Bool
} derive(Debug)

///|
struct Doc {
  parts : Array[Part]
  tail : String?
  trailing_ws : String
} derive(Debug)

///|
fn Doc::render(self : Doc) -> (String, Array[(String, Bool)]) {
  let buf = StringBuilder()
  let stmts = []
  let n = self.parts.length()
  for i, part in self.parts {
    buf.write_string(part.lead)
    let terminated = part.has_semi || i < n - 1 || self.tail is Some(_)
    let verbatim = part.text +
      (if terminated { part.semi_ws + ";" } else { "" })
    buf.write_string(verbatim)
    stmts.push((verbatim, part.skipped))
  }
  if self.tail is Some(tail) {
    buf.write_string("\n")
    buf.write_string(tail)
    stmts.push((tail, true))
  }
  buf.write_string(self.trailing_ws)
  (buf.to_string(), stmts)
}

///|
fn Doc::text(self : Doc) -> String {
  self.render().0
}

///|
fn Doc::stmts(self : Doc) -> Array[(String, Bool)] {
  self.render().1
}

///|
impl @quickcheck.Arbitrary for Doc with fn arbitrary(size, rs) {
  let g = Gen::new(rs)
  let parts = []
  for _ in 0..<(1 + g.below(size.min(6) + 1)) {
    let (text, skipped) = g.statement()
    parts.push({
      lead: if parts.is_empty() {
        g.pick(["", "", "\n", "  ", "\n\n"])
      } else {
        g.pick(["\n\n", "\n", " ", "", "\n  ", "\r\n\r\n"])
      },
      text,
      semi_ws: g.pick(["", "", " ", "\n"]),
      has_semi: g.chance(2),
      skipped,
    })
  }
  let tail = if g.chance(6) {
    g.out.clear()
    g.comment()
    Some(g.out[0])
  } else {
    None
  }
  { parts, tail, trailing_ws: g.pick(["", "", "\n", "  \n\n", " "]), }
}

///|
impl @quickcheck.Shrink for Doc with fn shrink(self) {
  let by_part = Array::makei(self.parts.length(), i => i)
    .iter()
    .filter(_ => self.parts.length() > 1)
    .map(i => {
      let parts = self.parts.copy()
      ignore(parts.remove(i))
      { ..self, parts, }
    })
  let no_tail = match self.tail {
    Some(_) => Iter::singleton({ ..self, tail: None, })
    None => Iter::empty()
  }
  by_part.concat(no_tail)
}

///|
priv struct Soup {
  text : String
} derive(Debug)

///|
let soup_words : Array[String] = [
  "select", "from", "where", "and", "or", "on", "as", "set", "update", "delete",
  "insert", "into", "values", "returning", "with", "limit", "having", "union", "like",
  "not", "null", "is", "in", "case", "when", "join", "unique", "default", "recursive",
  "desc", "all", "group", "by", "order", "left", "outer", "create", "table", "view",
  "index", "virtual", "or", "replace", "ignore", "conflict", "do", "nothing", "without",
  "rowid", "if", "exists", "primary", "key", "references", "a", "é", "日", "😀",
  "t_1", "x", "42", "1.5", "0x1F", "'s'", "''", "'a;b'", "\"q\"", "`b`", "[c]", "?",
  ":n", "@p", "$q", "||", "<>", "<=", "!=", "=", "+", "-", "*", "/", ".", "~", "&",
  "<<",
]

///|
impl @quickcheck.Arbitrary for Soup with fn arbitrary(size, rs) {
  let g = Gen::new(rs)
  for _ in 0..<g.below(size.min(60) + 1) {
    match g.below(10) {
      0 => g.raw("(")
      1 => g.raw(")")
      2 => g.raw(",")
      3 => g.raw(";")
      4 => g.comment()
      _ => g.raw(g.pick(soup_words))
    }
  }
  { text: g.join_pieces(g.out), }
}

///|
impl @quickcheck.Shrink for Soup with fn shrink(self) {
  let words = self.text.split(" ").collect()
  Array::makei(words.length(), i => i)
  .iter()
  .map(i => {
    let kept = words.copy()
    ignore(kept.remove(i))
    { text: kept.iter().join(" "), }
  })
}
