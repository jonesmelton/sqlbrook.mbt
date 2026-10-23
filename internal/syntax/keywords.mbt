///|
fn is_clause_starter(k : String) -> Bool {
  match k {
    "select"
    | "update"
    | "delete"
    | "set"
    | "returning"
    | "from"
    | "where"
    | "group by"
    | "having"
    | "order by"
    | "limit"
    | "on"
    | "join"
    | "inner join"
    | "left join"
    | "cross join"
    | "left outer join"
    | "right outer join"
    | "full outer join" => true
    _ => false
  }
}

///|
fn is_expr_keyword(k : String) -> Bool {
  match k {
    "is"
    | "not"
    | "null"
    | "like"
    | "glob"
    | "in"
    | "between"
    | "exists"
    | "desc"
    | "asc"
    | "distinct"
    | "collate"
    | "all" => true
    _ => false
  }
}

///|
/// Clauses whose body is one predicate, split at depth-0 `and`/`or`.
fn is_predicate_keyword(k : String) -> Bool {
  match k {
    "where" | "having" | "on" | "and" | "or" => true
    _ => false
  }
}

///|
fn is_insert_verb(k : String) -> Bool {
  match k {
    "insert" | "insert or replace" | "insert or ignore" => true
    _ => false
  }
}

///|
fn is_ddl_break(k : String) -> Bool {
  match k {
    "not"
    | "default"
    | "references"
    | "collate"
    | "check"
    | "unique"
    | "primary key"
    | "foreign key"
    | "on conflict" => true
    _ => false
  }
}
