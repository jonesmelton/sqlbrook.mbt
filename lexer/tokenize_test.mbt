///|
fn describe(t : @lexer.Token) -> String {
  match t {
    Keyword(s) => "kw    \{s}"
    Ident(s) => "id    \{s}"
    Quoted(s) => "quot  \{s}"
    Number(s) => "num   \{s}"
    Operator(s) => "op    \{s}"
    Placeholder(s) => "ph    \{s}"
    LParen => "lparen"
    RParen => "rparen"
    Comma => "comma"
    Semicolon => "semi"
    Comment(s) => "comm  \{s}"
  }
}

///|
fn show(source : String) -> String raise @lexer.LexError {
  @lexer.tokenize(source).map(describe).join("\n")
}

///|
test "lexer: multi-word keyword normalization" {
  inspect(
    show("SELECT x FROM t ORDER  BY y DESC"),
    content=(
      #|kw    select
      #|id    x
      #|kw    from
      #|id    t
      #|kw    order by
      #|id    y
      #|kw    desc
    ),
  )
  inspect(
    show("insert OR replace into t values (1) on conflict ignore"),
    content=(
      #|kw    insert or replace
      #|kw    into
      #|id    t
      #|kw    values
      #|lparen
      #|num   1
      #|rparen
      #|kw    on conflict
      #|id    ignore
    ),
  )
  inspect(
    show("create table if not exists s.t (k integer primary key)"),
    content=(
      #|kw    create table
      #|kw    if not exists
      #|id    s.t
      #|lparen
      #|id    k
      #|id    integer
      #|kw    primary key
      #|rparen
    ),
  )
  inspect(
    show("select \"order\" from orders inner join lines on a.id = b.id"),
    content=(
      #|kw    select
      #|quot  "order"
      #|kw    from
      #|id    orders
      #|kw    inner join
      #|id    lines
      #|kw    on
      #|id    a.id
      #|op    =
      #|id    b.id
    ),
  )
}

///|
test "lexer: placeholder forms (:name @name $name ?NNN ?)" {
  inspect(
    show("select :name, @name, $name, ?17, ? from t"),
    content=(
      #|kw    select
      #|ph    :name
      #|comma
      #|ph    @name
      #|comma
      #|ph    $name
      #|comma
      #|ph    ?17
      #|comma
      #|ph    ?
      #|kw    from
      #|id    t
    ),
  )
}

///|
test "lexer: quoted identifiers and non-ascii bytes pass through" {
  inspect(
    show(
      "select 'café ''quoted''', \"tablé\", `tick`, [bracket], résumé from t",
    ),
    content=(
      #|kw    select
      #|quot  'café ''quoted'''
      #|comma
      #|quot  "tablé"
      #|comma
      #|quot  `tick`
      #|comma
      #|quot  [bracket]
      #|comma
      #|id    résumé
      #|kw    from
      #|id    t
    ),
  )
}

///|
test "lexer: comments, operators, numbers" {
  inspect(
    show(
      "--name: find\nselect a || '%', 1.5, 0x1f, .5 from t where a <> b and c >= 2 - 1\n-- trailing",
    ),
    content=(
      #|comm  --name: find
      #|kw    select
      #|id    a
      #|op    ||
      #|quot  '%'
      #|comma
      #|num   1.5
      #|comma
      #|num   0x1f
      #|comma
      #|num   .5
      #|kw    from
      #|id    t
      #|kw    where
      #|id    a
      #|op    <>
      #|id    b
      #|kw    and
      #|id    c
      #|op    >=
      #|num   2
      #|op    -
      #|num   1
      #|comm  -- trailing
    ),
  )
}
