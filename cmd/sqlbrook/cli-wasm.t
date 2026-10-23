Cases specific to the stdin-only wasm CLI. @VERSION@ is replaced with the
version in moon.mod by scripts/cli_test.mbtx.

--version prints the module version:

  $ sqlbrook --version
  @VERSION@

File arguments and file flags do not exist; the rejected input is named and
the message points at --help:

  $ printf 'select 1;' | sqlbrook foo.sql
  sqlbrook: unexpected value 'foo.sql' found; no more were expected, run `sqlbrook --help`
  [2]

  $ printf 'select 1;' | sqlbrook -w
  sqlbrook: unexpected argument '-w' found, run `sqlbrook --help`
  [2]

  $ printf 'select 1;' | sqlbrook --output=x.sql
  sqlbrook: unexpected argument '--output' found, run `sqlbrook --help`
  [2]

  $ printf 'select 1;' | sqlbrook --bogus 2>/dev/null
  [2]

--help documents the exit codes and exits 0:

  $ sqlbrook --help | grep -c '^  [0-3]  '
  4

--man exits 0 without reading stdin:

  $ sqlbrook --man </dev/null | head -1
  sqlbrook(1)

  $ sqlbrook --man </dev/null | grep -c 'create index'
  1

Invalid UTF-8 is rejected with the byte offset, exit 2, empty stdout:

  $ printf 'select \377 from t;' | sqlbrook
  sqlbrook: <stdin>: invalid UTF-8 at offset 7
  sqlbrook: <stdin>: input is not lexable SQLite SQL; check for stray bytes or host-language interpolation (use bind parameters instead)
  [2]

  $ printf 'select \303 from t;' | sqlbrook 2>/dev/null
  [2]

Valid multibyte UTF-8 in identifiers is accepted:

  $ printf 'select caf\303\251 from t;' | sqlbrook
  select café
    from t
         ;
