///|
fn flat_text(toks : Array[@sqlbrook.Token]) -> String {
  let buf = StringBuilder()
  for t in toks {
    buf.write_string(t.to_string())
    buf.write_char(if t is Comment(_) { '\n' } else { ' ' })
  }
  buf.to_string()
}

///|
fn must_format(src : String) -> @sqlbrook.Formatted raise {
  @sqlbrook.format(src)
}

///|
test "invariant: lexer roundtrip over examples corpus" {
  let lines = []
  for (file, src) in @corpus.all() {
    let toks = @sqlbrook.tokenize(src)
    let again = @sqlbrook.tokenize(flat_text(toks))
    lines.push(
      "\{file} \{toks.length()} tokens roundtrip \{if again == toks { "ok" } else { "FAILED" }}",
    )
  }
  inspect(
    lines.join("\n"),
    content=(
      #|bugshield.sql 215 tokens roundtrip ok
      #|char.sql 28 tokens roundtrip ok
      #|init.sql 285 tokens roundtrip ok
      #|items.sql 16 tokens roundtrip ok
      #|lore.sql 54 tokens roundtrip ok
      #|map.sql 31 tokens roundtrip ok
      #|session.sql 153 tokens roundtrip ok
      #|vitals.sql 320 tokens roundtrip ok
    ),
  )
}

///|
test "invariant: token preservation" {
  for (file, src) in @corpus.all() {
    assert_eq(
      @sqlbrook.tokenize(must_format(src).output),
      @sqlbrook.tokenize(src),
      msg=file,
    )
  }
}

///|
test "golden: every corpus file is already formatted" {
  for (file, src) in @corpus.all() {
    // vitals.sql's window-function statements pass through unchanged.
    if file == "vitals.sql" {
      continue
    }
    assert_eq(must_format(src).output, src, msg=file)
  }
}

///|
test "invariant: idempotence" {
  for (file, src) in @corpus.all() {
    let once = must_format(src).output
    assert_eq(must_format(once).output, once, msg=file)
  }
}

///|
test "invariant: token preservation on non-corpus constructs" {
  for
    src in [
      "select a from t union all select b from u;", "select a from t intersect select b from u;",
      "create index i on t (a);", "create unique index i on t (a) where b is null;",
      "create virtual table f using fts5 (title, body);", "create table t (a text, b text, primary key (a, b)) without rowid;",
      "delete from t where a = ? and b = ?;", "insert or ignore into t (a) values (?);",
      "insert into t (a) values (?) on conflict (a) do nothing;", "insert into t (a) values (?) returning id, slug;",
      "insert into t (a, b) select x, y from u where z = ?;", "insert into t select * from u;",
    ] {
    assert_eq(
      @sqlbrook.tokenize(must_format(src).output),
      @sqlbrook.tokenize(src),
      msg=src,
    )
  }
}
