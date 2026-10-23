///|
/// Length of the UTF-8 encoding of `s`, without allocating it.
///
/// Every layout width and error offset is measured in UTF-8 bytes, matching
/// the reference implementation, so a column of non-ASCII identifiers aligns
/// by byte count rather than by display width. A lone surrogate counts as 3,
/// the width of its WTF-8 encoding.
pub fn utf8_width(s : StringView) -> Int32 {
  let n = s.length()
  let mut width = 0
  let mut i = 0
  while i < n {
    let c = s.unsafe_get(i)
    if c < 0x80 {
      width += 1
    } else if c < 0x800 {
      width += 2
    } else if c.is_leading_surrogate() &&
      i + 1 < n &&
      s.unsafe_get(i + 1).is_trailing_surrogate() {
      width += 4
      i += 1
    } else {
      width += 3
    }
    i += 1
  }
  width
}
