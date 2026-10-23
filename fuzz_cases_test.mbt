///|
/// Fragments for character-level soup: half-lexemes, quote and bracket
/// openers, error bytes, and keywords that steer the parser.
let fuzz_fragments : Array[String] = [
  "a", "B", "1", "0x", "e", ".", ":", "@", "$", "?", "'", "\"", "`", "[", "]", "(",
  ")", ",", ";", "-", "--", "\n", " ", "|", "<", ">", "=", "!", "é", "😀", "\u{1}",
  "#", "select", "from", "where", "order by", "insert into", "values", "create table",
  "with", "as", "union", "case", "end", "between", "and",
]

///|
/// Prints differential-fuzzing inputs for `scripts/oracle.mbtx --fuzz`, one
/// JSON string per line. Skipped by default; it asserts nothing.
#skip("input generator for scripts/oracle.mbtx")
test "fuzz cases" {
  let rs = @quickcheck.RandomState(seed=42UL)
  for i in 0..<3000 {
    let doc : Doc = @quickcheck.Arbitrary::arbitrary(i % 40 + 1, rs)
    println(Json(doc.text()).stringify())
  }
  for i in 0..<3000 {
    let soup : Soup = @quickcheck.Arbitrary::arbitrary(i % 60 + 1, rs)
    println(Json(soup.text).stringify())
  }
  let g = Gen::new(rs)
  for i in 0..<3000 {
    let buf = StringBuilder()
    for _ in 0..<g.below(i % 30 + 2) {
      buf.write_string(g.pick(fuzz_fragments))
    }
    println(Json(buf.to_string()).stringify())
  }
}
