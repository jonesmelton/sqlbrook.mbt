///|
test "utf8_error_offset points at the first invalid sequence" {
  // A stray continuation byte, a truncated two-byte sequence, an encoded
  // surrogate, an overlong encoding, and valid input.
  inspect(utf8_error_offset(b"select \xff"), content="7")
  inspect(utf8_error_offset(b"ab\xc3"), content="2")
  inspect(utf8_error_offset(b"\"\xed\xa0\x80\""), content="1")
  inspect(utf8_error_offset(b"a\xe0\x80\xaf"), content="1")
  inspect(utf8_error_offset(b"caf\xc3\xa9"), content="5")
}
