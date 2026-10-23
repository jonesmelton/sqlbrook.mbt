///|
/// The table name right-aligned to the river, each definition's lead token
/// right-aligned under it with a glued leading comma, and each constraint
/// segment on its own continuation line.
fn create_table_lines(
  lines : Array[String],
  header : Array[@lexer.Token],
  name : Array[@lexer.Token],
  defs : Array[@syntax.DdlItem],
  without_rowid : Bool,
  semi : Bool,
  r : Int32,
) -> Unit {
  lines.push(render_tokens(header))
  let name_text = render_tokens(name)
  lines.push(pad(r - @text.utf8_width(name_text)) + name_text + " (")
  for i, { lead, head_rest, segments, } in defs {
    let lead_text = lead.to_string()
    let lead_col = if i == 0 {
      pad(r - @text.utf8_width(lead_text)) + lead_text
    } else {
      pad(r - 1 - @text.utf8_width(lead_text)) + "," + lead_text
    }
    if head_rest.is_empty() {
      lines.push(lead_col)
    } else {
      lines.push(lead_col + " " + render_tokens(head_rest))
    }
    for segment in segments {
      let indent = if segment is [Keyword("on conflict"), ..] {
        r + 2
      } else {
        r + 1
      }
      lines.push(pad(indent) + render_tokens(segment))
    }
  }
  if without_rowid {
    lines.push(pad(r - 1) + ")")
    lines.push(pad(r - 13) + "without rowid")
    if semi {
      lines.push(pad(r + 1) + ";")
    }
  } else {
    lines.push(pad(r - 1) + (if semi { ") ;" } else { ")" }))
  }
}
