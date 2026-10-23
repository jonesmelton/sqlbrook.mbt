///|
/// The river column of `stmt`: the width of its widest left-column text, in
/// UTF-8 bytes. Clause keywords and leading commas are right-aligned to it.
fn river_width(stmt : @syntax.Stmt) -> Int32 {
  match stmt {
    Dml(clauses~, ..) => {
      let mut width = 0
      for { kw, .. } in clauses {
        width = width.max(@text.utf8_width(kw))
      }
      width
    }
    // `insert` keeps `into <table>` on its own line with the river at the
    // right edge of `into`; a longer verb breaks onto its own line and the
    // river falls back to `values`.
    Insert({ verb, .. }) => if verb == "insert" { 11 } else { 6 }
    CreateTable(name~, defs~, ..) => {
      let mut width = @text.utf8_width(render_tokens(name))
      for i, { lead, .. } in defs {
        let lead_width = @text.utf8_width(lead.to_string()) +
          (if i == 0 { 0 } else { 1 })
        width = width.max(lead_width)
      }
      width
    }
    CreateView(body~, ..) => river_width(body)
    Cte(recursive~, ..) => if recursive { 14 } else { 4 }
    Setop(op~, arms~, ..) => {
      let mut width = @text.utf8_width(op)
      for arm in arms {
        width = width.max(river_width(arm))
      }
      width
    }
    CreateIndex(verb~, ..) | CreateVirtualTable(verb~, ..) =>
      @text.utf8_width(verb)
    Passthrough(..) => 0
  }
}
