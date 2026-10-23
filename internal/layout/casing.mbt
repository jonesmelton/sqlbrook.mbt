///|
/// The set is closed: an unrecognized call-shaped identifier is a user-defined
/// or extension function and keeps its spelling.
fn is_builtin_function(lw : String) -> Bool {
  match lw {
    "count"
    | "sum"
    | "avg"
    | "min"
    | "max"
    | "total"
    | "group_concat"
    | "string_agg"
    | "abs"
    | "coalesce"
    | "ifnull"
    | "iif"
    | "nullif"
    | "length"
    | "lower"
    | "upper"
    | "ltrim"
    | "rtrim"
    | "trim"
    | "replace"
    | "substr"
    | "substring"
    | "instr"
    | "hex"
    | "unhex"
    | "quote"
    | "char"
    | "unicode"
    | "format"
    | "printf"
    | "glob"
    | "like"
    | "likelihood"
    | "likely"
    | "unlikely"
    | "random"
    | "randomblob"
    | "zeroblob"
    | "typeof"
    | "round"
    | "sign"
    | "cast"
    | "date"
    | "time"
    | "datetime"
    | "julianday"
    | "unixepoch"
    | "strftime"
    | "timediff"
    | "row_number"
    | "rank"
    | "dense_rank"
    | "percent_rank"
    | "cume_dist"
    | "ntile"
    | "lag"
    | "lead"
    | "first_value"
    | "last_value"
    | "nth_value" => true
    _ => false
  }
}

///|
fn is_type_name(lw : String) -> Bool {
  match lw {
    "text"
    | "integer"
    | "int"
    | "real"
    | "blob"
    | "numeric"
    | "boolean"
    | "date"
    | "datetime"
    | "varchar"
    | "char"
    | "decimal"
    | "double"
    | "float"
    | "smallint"
    | "bigint" => true
    _ => false
  }
}

///|
/// The spelling of identifier `w`: a builtin function name is lowercased only
/// when call-shaped (directly before its `(`), a type name only when not, and
/// anything else keeps its spelling.
fn normalize_ident(w : String, followed_by_lparen~ : Bool) -> String {
  let lw = @text.ascii_lowercase(w)
  if followed_by_lparen {
    if is_builtin_function(lw) {
      lw
    } else {
      w
    }
  } else if is_type_name(lw) {
    lw
  } else {
    w
  }
}
