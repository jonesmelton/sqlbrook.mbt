///|
/// The byte offset of the first invalid UTF-8 sequence in `bytes`, or its
/// length when there is none.
fn utf8_error_offset(bytes : Bytes) -> Int32 {
  let mut i = 0
  while i < bytes.length() {
    let b = bytes[i].to_int()
    let len = if b < 0x80 {
      1
    } else if b >= 0xC2 && b <= 0xDF {
      2
    } else if b >= 0xE0 && b <= 0xEF {
      3
    } else if b >= 0xF0 && b <= 0xF4 {
      4
    } else {
      return i
    }
    if i + len > bytes.length() {
      return i
    }
    try @utf8.decode(bytes[i:i + len]) catch {
      _ => return i
    } noraise {
      _ => ()
    }
    i += len
  }
  i
}
