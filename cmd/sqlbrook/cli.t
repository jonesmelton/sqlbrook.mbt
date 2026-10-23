Exit-code contract for the sqlbrook CLI on stdin. Every case here also holds
for the OCaml binary: run
`moon run scripts/cli_test.mbtx -- /path/to/oracle` to check.

A formatted select round-trips to exit 0 with no stderr:

  $ printf 'select a\n  from t\n       ;\n' | sqlbrook
  select a
    from t
         ;

Unformatted input is rewritten on stdout, exit 0:

  $ printf 'select a from t;' | sqlbrook
  select a
    from t
         ;

Empty input formats to empty output:

  $ printf '' | sqlbrook

An unsupported construct still echoes on stdout but the exit is 3:

  $ printf 'select rank() over (order by xp) from t;' | sqlbrook
  select rank() over (order by xp) from t;
  sqlbrook: <stdin>: line 1: select not yet formatted, passed through
  [3]

Unlexable input: exit 2, empty stdout, located message plus redirect hint:

  $ printf 'select \001 from t;' | sqlbrook
  sqlbrook: <stdin>: unexpected byte '\001' at offset 7
  sqlbrook: <stdin>: input is not lexable SQLite SQL; check for stray bytes or host-language interpolation (use bind parameters instead)
  [2]

  $ printf 'select \001 from t;' | sqlbrook 2>/dev/null
  [2]

PostgreSQL syntax names the dialect, so the generic hint is suppressed:

  $ printf 'select a::int from t;' | sqlbrook
  sqlbrook: <stdin>: '::' is not SQLite syntax (PostgreSQL cast) at offset 8; dialect is SQLite
  [2]

  $ printf 'select $$x$$;' | sqlbrook
  sqlbrook: <stdin>: '$$' is not SQLite syntax (PostgreSQL dollar-quote) at offset 7; dialect is SQLite
  [2]

--check on already-formatted input: exit 0, nothing on stdout or stderr.

  $ printf 'select a\n  from t\n       ;\n' | sqlbrook --check

--check on unformatted-but-supported input: exit 1, no formatted output.

  $ printf 'select a from t;' | sqlbrook --check
  sqlbrook: <stdin>: not formatted
  [1]

--check where passthrough is present: passthrough wins (3), even though the
input is also "not formatted", and nothing is written to stdout:

  $ printf 'select rank() over (order by xp) from t;' | sqlbrook --check 2>/dev/null
  [3]

  $ printf 'select rank() over (order by xp) from t;' | sqlbrook --check
  sqlbrook: <stdin>: line 1: select not yet formatted, passed through
  sqlbrook: <stdin>: not formatted
  [3]

--check with unlexable input: 2 outranks everything.

  $ printf 'select \001 from t;' | sqlbrook --check
  sqlbrook: <stdin>: unexpected byte '\001' at offset 7
  sqlbrook: <stdin>: input is not lexable SQLite SQL; check for stray bytes or host-language interpolation (use bind parameters instead)
  [2]
