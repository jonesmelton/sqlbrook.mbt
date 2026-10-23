///|
pub fn render_stmt(stmt : @syntax.Stmt) -> String {
  stmt_lines(stmt).join("\n")
}

///|
fn pad(n : Int32) -> String {
  " ".repeat(n.max(0))
}

///|
fn shifted(n : Int32, lines : Array[String]) -> Array[String] {
  lines.map(line => pad(n) + line)
}

///|
/// The lines of `stmt`. `river` overrides the river column of a clause
/// sequence, so the arms of a set operation and an `insert ... select` share
/// one river.
fn stmt_lines(stmt : @syntax.Stmt, river? : Int32) -> Array[String] {
  let lines = []
  match stmt {
    Passthrough(source~, ..) => lines.push(source)
    Dml(clauses~, semi~) =>
      dml_lines(
        lines,
        clauses,
        semi,
        river.unwrap_or_else(() => river_width(stmt)),
      )
    Cte(recursive~, name~, cols~, body~, outer~) => {
      let r = river_width(stmt)
      let head = if recursive { "with recursive " } else { "with " }
      if cols.is_empty() {
        lines.push(head + name + " as (")
      } else {
        lines.push(head + name)
        paren_block(lines, r, cols, pad(r - 1) + ") as (")
      }
      lines.append(shifted(r + 2, stmt_lines(body)))
      lines.push(pad(r + 1) + ")")
      lines.append(stmt_lines(outer))
    }
    Setop(op~, arms~, semi~) => {
      let r = river_width(stmt)
      for i, arm in arms {
        if i > 0 {
          lines.push(pad(r - @text.utf8_width(op)) + op)
        }
        lines.append(stmt_lines(arm, river=r))
      }
      if semi {
        lines.push(pad(r + 1) + ";")
      }
    }
    CreateView(header~, body~) => {
      lines.push(render_tokens(header))
      lines.push(pad(river_width(body) - 2) + "as")
      lines.append(stmt_lines(body))
    }
    Insert(insert) => insert_lines(lines, insert, river_width(stmt))
    CreateTable(header~, name~, defs~, without_rowid~, semi~) =>
      create_table_lines(
        lines,
        header,
        name,
        defs,
        without_rowid,
        semi,
        river_width(stmt),
      )
    CreateIndex(verb~, name~, table~, predicate~, semi~) => {
      let r = river_width(stmt)
      lines.push(verb + " " + render_tokens(name))
      match table {
        [Keyword("on"), .. rest] =>
          lines.push(pad(r - 2) + "on " + render_tokens(rest))
        _ => lines.push(pad(r + 1) + render_tokens(table))
      }
      if !predicate.is_empty() {
        lines.push(pad(r - 5) + "where " + render_tokens(predicate))
      }
      if semi {
        lines.push(pad(r + 1) + ";")
      }
    }
    CreateVirtualTable(verb~, name~, module_args~, semi~) => {
      let r = river_width(stmt)
      lines.push(verb + " " + render_tokens(name))
      match module_args {
        [Keyword("using"), .. rest] =>
          lines.push(pad(r - 5) + "using " + render_tokens(rest))
        _ => lines.push(pad(r + 1) + render_tokens(module_args))
      }
      if semi {
        lines.push(pad(r + 1) + ";")
      }
    }
  }
  lines
}

///|
fn dml_lines(
  lines : Array[String],
  clauses : Array[@syntax.Clause],
  semi : Bool,
  width : Int32,
) -> Unit {
  for { kw, items, } in clauses {
    let kw_pad = pad(width - @text.utf8_width(kw))
    if items.is_empty() {
      lines.push(kw_pad + kw)
    }
    for i, { expr, as_name, } in items {
      let lead = if i == 0 { kw_pad + kw + " " } else { pad(width - 1) + ", " }
      lines.append(item_lines(width, lead, expr))
      if as_name is Some(name) {
        lines.push(pad(width - 2) + "as " + name)
      }
    }
  }
  if semi {
    lines.push(pad(width + 1) + ";")
  }
}

///|
fn paren_block(
  lines : Array[String],
  river : Int32,
  items : Array[@syntax.Item],
  close : String,
) -> Unit {
  for i, { expr, .. } in items {
    let lead = pad(river - 1) + (if i == 0 { "( " } else { ", " })
    lines.append(item_lines(river, lead, expr))
  }
  lines.push(close)
}

///|
fn item_lines(
  width : Int32,
  lead : String,
  body : @syntax.ItemBody,
) -> Array[String] {
  match body {
    Blob(toks) => [lead + render_tokens(toks)]
    Sub(inner) => {
      let lines = [lead + "("]
      lines.append(shifted(width + 2, stmt_lines(inner)))
      lines.push(pad(width + 1) + ")")
      lines
    }
  }
}
