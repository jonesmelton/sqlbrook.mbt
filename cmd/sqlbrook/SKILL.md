---
name: sqlbrook
description: Format or check SQLite SQL in the "river" style (lowercase keywords, clause keywords right-aligned to a common column, leading commas, one expression per line) by piping it through the sqlbrook wasm binary on stdin. Use when asked to format, tidy, or verify the formatting of SQLite statements, including queries embedded in other files. SQLite only; PostgreSQL and MySQL syntax is rejected.
---

# sqlbrook

`sqlbrook` reads SQLite SQL on stdin and writes the same SQL, token for token, laid out in the river style on stdout. It has no file arguments and no in-place mode.

## Invocation

```sh
printf '%s\n' "$sql" | moonx jonesmelton/sqlbrook/cmd/sqlbrook
moonx jonesmelton/sqlbrook/cmd/sqlbrook -- --check < query.sql
```

`moon runwasm jonesmelton/sqlbrook/cmd/sqlbrook` is the deprecated spelling of the same command. After `moon install jonesmelton/sqlbrook/cmd/sqlbrook`, a native `sqlbrook` on PATH behaves identically. From a checkout, `moon run --target wasm cmd/sqlbrook -- --check < query.sql` works.

| Flag | Effect |
| --- | --- |
| `--check` | Write nothing to stdout. Exit 1 and print `sqlbrook: <stdin>: not formatted` on stderr if the input differs from the formatted output. |
| `--man` | Print the full contract (statement scope, exit codes, embedded queries). |
| `--help`, `--version` | Usage and version. |

Input must be valid UTF-8. Output ends with a newline, so end the input with one when you compare it to the output.

## Exit codes

Branch on the exit code. stdout is either valid SQL or empty, and diagnostics go to stderr.

| Code | Meaning | Action |
| --- | --- | --- |
| 0 | Fully formatted, nothing passed through | Use stdout. |
| 1 | `--check` only: input is not already formatted | Run again without `--check` to get the formatted text. |
| 2 | Usage error, invalid UTF-8, or input that is not lexable SQLite SQL. stdout is empty. | Leave the input alone and report the stderr message. |
| 3 | A statement passed through unformatted. stdout still holds the whole input, with passed-through statements verbatim. | Use stdout, or leave the input alone. Report the skipped lines from stderr. |

When signals combine, 2 outranks 3, and 3 outranks 1.

Exit 2 covers `::` casts, `$$` quoting, stray control bytes, and host-language interpolation sitting where a bind parameter belongs. Do not hand-fix these; report them.

## Scope

Laid out: `select` (including `group by`, `having`, `case`), `insert` (including `or replace`, `or ignore`, `insert ... select`, `on conflict`, `returning`), `update`, `delete`, single-CTE queries, set operations that use one operator kind, `create table`, `create view`, `create index`, `create virtual table`.

Passed through verbatim, exit 3: multi-row `values`, multi-CTE queries, set operations that mix operator kinds, window functions (`over`), standalone comments, and every other statement (`alter`, `drop`, `pragma`, transactions, triggers, `replace into`).

Never predict the output by hand. Alignment depends on the whole statement, so run the tool.

## Embedded queries

The river is laid out at column 0 and there is no indent option.

1. Extract the SQL from the host file. Write it as a string literal that starts with a newline so the statement begins at column 0, and remove the literal's common indentation.
2. Pipe it through `sqlbrook`. On exit 0, take stdout. On 2 or 3, leave the literal unchanged.
3. Splice stdout back in verbatim and restore the literal's indentation.

Use SQLite bind parameters (`:name`, `@name`, `$name`, `?`, `?NNN`) for values. Host-language string interpolation makes the input unlexable.
