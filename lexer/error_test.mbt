///|
test "error: unlexable byte is a located error, not a crash" {
  try @lexer.tokenize("select \u{1} from t;") catch {
    e => inspect(e, content="unexpected byte '\\001' at offset 7")
  } noraise {
    _ => fail("expected LexError")
  }
}

///|
test "error: PostgreSQL syntax is named" {
  try @lexer.tokenize("select a::int") catch {
    PostgresCast(offset~) => assert_eq(offset, 8)
    e => fail("unexpected \{e}")
  } noraise {
    _ => fail("expected LexError")
  }
  try @lexer.tokenize("select $$x$$") catch {
    PostgresDollarQuote(offset~) => assert_eq(offset, 7)
    e => fail("unexpected \{e}")
  } noraise {
    _ => fail("expected LexError")
  }
}

///|
test "error: offsets count UTF-8 bytes" {
  try @lexer.tokenize("select 'é', #") catch {
    e => inspect(e, content="unexpected byte '#' at offset 13")
  } noraise {
    _ => fail("expected LexError")
  }
}
