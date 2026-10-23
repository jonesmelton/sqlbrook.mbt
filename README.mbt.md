# sqlbrook

A whole-statement SQLite formatter for the "river" style: lowercase keywords, clause keywords right-aligned to a common column, leading commas, one expression per line.

```sql
  select size
       , species
       , hits
    from bugshields
   where end_time is null
order by ts desc
   limit 1
         ;
```

sqlbrook only rearranges whitespace and case: the formatted output lexes to the same tokens as the input. Statements it does not lay out yet are copied verbatim and reported, never rewritten. It is a MoonBit port of the [OCaml implementation](https://github.com/jonesmelton/sqlbrook), and matches its output byte for byte. [`docs/style.md`](docs/style.md) specifies the style.

## Install

As a library:

```sh
moon add jonesmelton/sqlbrook
```

As a command-line tool, run it without installing, or install a native binary to `~/.moon/bin`:

```sh
moonx jonesmelton/sqlbrook/cmd/sqlbrook < query.sql
moon install jonesmelton/sqlbrook/cmd/sqlbrook
```

## Library

`@sqlbrook.format` takes SQL text and returns the formatted text plus the statements it passed through. It works on every MoonBit backend.

```mbt check
///|
test "format lays out a select" {
  let r = @sqlbrook.format("SELECT a, COUNT(*) AS n FROM t GROUP BY a;")
  inspect(
    r.output,
    content=(
      #|  select a
      #|       , count(*)
      #|      as n
      #|    from t
      #|group by a
      #|         ;
      #|
    ),
  )
  assert_false(r.had_passthrough())
}
```

A statement outside the supported grammar is not an error. It appears in the output exactly as written, and `skips` records its leading keyword and 1-based line:

```mbt check
///|
test "unsupported statements pass through and are reported" {
  let r = @sqlbrook.format("select a from t;\nvacuum;")
  inspect(
    r.output,
    content=(
      #|select a
      #|  from t
      #|       ;
      #|
      #|vacuum;
      #|
    ),
  )
  debug_inspect(
    r.skips,
    content=(
      #|[{ kind: "vacuum", line: 2 }]
    ),
  )
}
```

Input that is not lexable SQLite SQL raises `LexError`, located by UTF-8 byte offset. PostgreSQL syntax gets its own message:

```mbt check
///|
test "PostgreSQL syntax raises LexError" {
  try @sqlbrook.format("select a::int from t;") catch {
    err =>
      inspect(
        err,
        content="'::' is not SQLite syntax (PostgreSQL cast) at offset 8; dialect is SQLite",
      )
  } noraise {
    _ => fail("expected LexError")
  }
}
```

`@sqlbrook.tokenize` exposes the lexer, which is useful for checking that two texts differ only in layout. `jonesmelton/sqlbrook/lexer` also provides `lex`, which returns each token with its source range.

```mbt check
///|
test "formatting preserves the token stream" {
  let src = "select a,b from t where x=1;"
  assert_eq(
    @sqlbrook.tokenize(@sqlbrook.format(src).output),
    @sqlbrook.tokenize(src),
  )
}
```

## Command line

`sqlbrook` reads SQL on stdin and writes formatted SQL on stdout. It has no file arguments and no in-place mode, so stdout is always either valid SQL or empty.

```sh
sqlbrook < query.sql            # format
sqlbrook --check < query.sql    # exit 1 if not already formatted; writes nothing
sqlbrook --man                  # the full contract: scope, exit codes, embedded queries
```

| Exit code | Meaning |
| --- | --- |
| 0 | Fully formatted, nothing passed through |
| 1 | `--check` found the input unformatted |
| 2 | Usage error, invalid UTF-8, or input that is not lexable SQLite SQL (stdout empty) |
| 3 | A statement passed through unformatted (stdout still holds the whole output) |

When several apply, 2 outranks 3, which outranks 1. Diagnostics go to stderr, naming the input `<stdin>`.

[`cmd/sqlbrook/SKILL.md`](cmd/sqlbrook/SKILL.md) packages the CLI as an agent skill, including how to format SQL embedded in other source files.

## Scope

Laid out:

- `select`, including joins, `group by`, `having`, `case`, and subqueries
- `insert`, including `or replace`, `or ignore`, `insert ... select`, `on conflict`, and `returning`
- `update` and `delete`
- queries with a single CTE, including `with recursive`
- set operations that use one operator kind (`union`, `union all`, `intersect`, `except`)
- `create table` (including `without rowid`), `create view`, `create index`, and `create virtual table`

Passed through verbatim: multi-row `values`, multiple CTEs, set operations that mix operator kinds, window functions, standalone comments, and every other statement (`alter`, `drop`, `pragma`, transactions, triggers, `replace into`, ...).

Widths are counted in UTF-8 bytes, as in the reference implementation, so a column of non-ASCII identifiers aligns by byte count rather than display width.

## Development

| Command | What it checks |
| --- | --- |
| `moon test --target all` | Unit, snapshot and property tests, the corpus invariants, and the examples in this README |
| `moon run scripts/cli_test.mbtx` | Builds the wasm CLI and runs its exit-code contract with `moon-cram` |
| `moon run scripts/cli_test.mbtx -- <bin>` | Runs the backend-independent part of that contract against another binary, such as the OCaml build or a native build |
| `moon run scripts/oracle.mbtx -- <ocaml-bin> [--fuzz]` | Compares stdout, stderr and exit status with the OCaml binary over the corpus, or over 9000 generated inputs |
| `moon run scripts/sync_corpus.mbtx -- <ocaml-repo>` | Refreshes `internal/corpus/` from the OCaml repository's examples |

Run `moon fmt` and `moon info` before committing, and review any change to a `pkg.generated.mbti`.

## License

MIT
