///|
fn lexes_equal(a : String, b : String) -> Bool {
  try @sqlbrook.tokenize(a) == @sqlbrook.tokenize(b) catch {
    _ => false
  } noraise {
    r => r
  }
}

///|
test "property: format is idempotent" {
  @quickcheck.check(
    (d : Doc) => {
      let once = @sqlbrook.format(d.text()).output
      @sqlbrook.format(once).output == once
    },
    count=500,
  )
}

///|
test "property: format preserves the token stream" {
  @quickcheck.check(
    (d : Doc) => lexes_equal(d.text(), @sqlbrook.format(d.text()).output),
    count=500,
  )
}

///|
test "property: skipped statements appear verbatim and are all reported" {
  @quickcheck.check(
    (d : Doc) => {
      let r = @sqlbrook.format(d.text())
      let stmts = d.stmts()
      let expected = stmts.iter().filter(s => s.1).count()
      r.skips.length() == expected &&
      stmts.iter().all(s => !s.1 || r.output.contains(s.0))
    },
    count=500,
  )
}

///|
test "property: format never raises on lexable token soup" {
  @quickcheck.check(
    (s : Soup) => {
      try @sqlbrook.format(s.text) catch {
        _ => false
      } noraise {
        _ => true
      }
    },
    count=500,
  )
}

///|
test "property: non-empty output ends in exactly one newline" {
  @quickcheck.check(
    (d : Doc) => {
      let out = @sqlbrook.format(d.text()).output
      out.is_empty() || (out.has_suffix("\n") && !out.has_suffix("\n\n"))
    },
    count=500,
  )
}

///|
test "property: soup output ends in exactly one newline and is a token fixed point" {
  @quickcheck.check(
    (s : Soup) => {
      let out = @sqlbrook.format(s.text).output
      (out.is_empty() || (out.has_suffix("\n") && !out.has_suffix("\n\n"))) &&
      lexes_equal(s.text, out) &&
      @sqlbrook.format(out).output == out
    },
    count=500,
  )
}
