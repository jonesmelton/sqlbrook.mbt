///|
/// Kept in step with `version` in moon.mod; `cli-wasm.t` checks the two agree.
const VERSION = "0.3.0"

///|
const MAN_PAGE =
  #|sqlbrook(1)
  #|
  #|DIALECT
  #|  SQLite only. PostgreSQL syntax (::cast, $$-quote) is reported as
  #|  unlexable (exit 2), not formatted. `backtick` and [bracket] quoted
  #|  identifiers are SQLite syntax and are kept as written.
  #|
  #|INPUT
  #|  UTF-8 SQL on stdin, formatted SQL on stdout. There are no file arguments,
  #|  -w, or -o. Input that is not valid UTF-8 is rejected (exit 2).
  #|
  #|STATEMENTS
  #|  Laid out:     select (group by, having, case), insert (incl. or replace,
  #|                or ignore, insert ... select, on conflict, returning),
  #|                update, delete, single-CTE queries, set operations with one
  #|                operator kind (union, intersect, ...), create table,
  #|                create view, create index, create virtual table.
  #|  Passed through (echoed verbatim, exit 3): multi-row values, multi-CTE
  #|                queries, set operations mixing operator kinds, window
  #|                functions (over), standalone comments, and every other
  #|                statement (alter, drop, pragma, transactions, triggers,
  #|                replace into, ...).
  #|
  #|EXIT CODES
  #|  0  input fully formatted; nothing passed through
  #|  1  --check found the input unformatted (but supported)
  #|  2  usage error, or input that isn't valid UTF-8 or lexable SQLite SQL
  #|  3  some statement passed through unformatted (an unsupported construct)
  #|  Precedence when signals combine: 2 outranks 3 outranks 1.
  #|
  #|STDOUT/STDERR
  #|  stdout carries only valid formatted SQL (or nothing); all diagnostics go to
  #|  stderr, with the input named <stdin>. Branch on the exit code. Unlexable
  #|  input yields empty stdout and a located message on stderr, never a crash
  #|  and never partial output. With --check, stdout is always empty.
  #|
  #|EMBEDDED QUERIES
  #|  The river is formatted at column 0; there is no --indent. Put embedded SQL in
  #|  a leading-newline string literal so the statement starts at column 0, then
  #|  extract -> run through sqlbrook -> splice back verbatim. Use bind parameters
  #|  (:name @name $name ? ?NNN), not host-language interpolation.

///|
fn command() -> @argparse.Command {
  @argparse.Command(
    "sqlbrook",
    about=(
      #|A whole-statement SQLite formatter for the river style.
      #|Reads SQL on stdin, writes formatted SQL on stdout.
      #|
      #|Exit codes:
      #|  0  fully formatted, nothing passed through
      #|  1  --check found the input unformatted
      #|  2  usage error, or input that is not valid UTF-8 or lexable SQLite SQL
      #|  3  some statement passed through unformatted (output is still emitted)
      #|
      #|Run --man for the statement scope and the embedded-query convention.
    ),
    version=VERSION,
    flags=[
      @argparse.FlagArg(
        "check",
        about="Write nothing; exit 1 if the input is not already formatted (3 takes precedence if a statement passes through).",
      ),
      @argparse.FlagArg(
        "man",
        about="Print the full operational contract and exit.",
      ),
    ],
  )
}
