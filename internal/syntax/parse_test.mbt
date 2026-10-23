///|
fn show_stmts(src : String) -> String raise @lexer.LexError {
  let lines = []
  for { stmt, .. } in @syntax.parse(src, @lexer.lex(src)) {
    match stmt {
      Passthrough(source~, ..) => lines.push("passthrough \{source.escape()}")
      _ => lines.push("parsed")
    }
  }
  lines.join("\n")
}

///|
test "statements split at top-level semicolons" {
  inspect(
    show_stmts("select 1;\n\nselect (2);"),
    content=(
      #|parsed
      #|parsed
    ),
  )
  inspect(
    show_stmts("select f(';') ; select 2"),
    content=(
      #|parsed
      #|parsed
    ),
  )
  inspect(
    show_stmts("--name: a\nselect 1;\n-- tail"),
    content=(
      #|parsed
      #|passthrough "-- tail"
    ),
  )
  inspect(show_stmts(""), content="")
}

///|
test "unsupported statements pass through with their kind and offset" {
  let src = "select 1;\n-- c\nvacuum;"
  let kinds = @syntax.parse(src, @lexer.lex(src)).map(p => {
    match p.stmt {
      Passthrough(kind~, offset~, source~) =>
        "\{kind} @\{offset} \{source.escape()}"
      _ => "parsed"
    }
  })
  inspect(
    kinds.join("\n"),
    content=(
      #|parsed
      #|vacuum @10 "-- c\nvacuum;"
    ),
  )
}
