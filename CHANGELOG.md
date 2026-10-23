# Changelog

## 0.3.0 (unreleased)

First MoonBit release, ported from the OCaml implementation at the same version and matching its output byte for byte.

- Library: `format`, `tokenize`, and the `lexer` package with source-spanned tokens. Runs on every backend.
- CLI: `cmd/sqlbrook`, a stdin-to-stdout formatter for wasm and native, with `--check` and `--man`. Unlike the OCaml CLI it takes no file arguments, and it rejects invalid UTF-8 with exit 2.
