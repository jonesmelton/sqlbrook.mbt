///|
test "property: utf8_width is the length of the UTF-8 encoding" {
  @quickcheck.check(
    (s : String) => @text.utf8_width(s) == @utf8.encode(s).length(),
    count=500,
  )
}

///|
test "utf8_width counts code points by encoded length" {
  inspect(@text.utf8_width("aé日😀"), content="10")
  inspect(@text.utf8_width(""), content="0")
}

///|
test "property: ascii_lowercase folds ASCII letters only" {
  @quickcheck.check(
    (s : String) => {
      let lowered = @text.ascii_lowercase(s)
      lowered.length() == s.length() &&
      s
      .iter()
      .zip(lowered.iter())
      .all(pair => {
        let (a, b) = pair
        b ==
        (if a is ('A'..<='Z') { (a.to_int() + 32).unsafe_to_char() } else { a })
      })
    },
    count=500,
  )
}

///|
test "ascii_lowercase leaves non-ASCII letters alone" {
  inspect(
    @text.ascii_lowercase("SELECT Été ÄÖ"),
    content="select Été ÄÖ",
  )
}
