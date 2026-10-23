# SQL style conventions

The river style that sqlbrook formats, as realized in `internal/corpus/*.sql`.

## Core principles

1. Keywords, recognized builtin functions, and type-affinity names are emitted
   lowercase. All other identifiers — table, column, and alias names, plus
   user-defined and extension functions — pass through as written. "Recognized"
   means a closed, curated set: a builtin function is lowercased only when it is
   call-shaped (immediately before its `(`), and a type name only when it is not
   call-shaped, so an unknown `MyFunc()` or a column literally named `Max` is
   left exactly as written.
2. Top-level clause keywords are right-aligned to a common column, forming a
   vertical "river" of whitespace after them:

   ```sql
     select size
          , species
       from bugshields
      where end_time is null
   order by ts desc
      limit 1
   ```

   The river column is set by the longest expression occupying the left
   column in the query.
3. Commas align in their own column under the start of the first item, with
   one space between comma and expression:

   ```sql
   select name
        , alignment
        , burden
   ```
4. The formatter arranges whitespace; it does not enforce token choices like
   `=` vs `is`.

## Select lists and aliases

- `as` is broken onto its own continuation line, indented so the alias hangs
  under the expression:

  ```sql
  select printf('%-18s', short_name)
      as short_name
       , printf('%-46s', full_name)
      as full_name
  ```

## Predicates

- One condition per line; `and`/`or` right-aligned into the river:

  ```sql
   where area = :area
     and full_name like '%' || :term || '%'
  ```

## Joins

- Explicit join keywords (`inner join`), river-aligned, with `on` on its own
  indented line:

  ```sql
        from rooms r
  inner join maps m
          on r.map_id = m.map_id
  ```
- Table aliases are written bare (no `as`), single-letter, prefixing every
  column reference when a join is present. This is a writing convention; the
  formatter keeps aliases as written.

## Insert statements

- The river column is the right edge of `into`; the table name sits in the
  content column. Column list in parens, one column per line with leading
  commas; the open paren takes the place of the comma on the first line
  (`( capname`). `values` gets its own river-aligned line, and the values
  block mirrors the column block exactly, line for line:

  ```sql
  insert into bugshields
            ( initial_size
            , size
            )
       values
            ( :size
            , :size
            ) returning *
              ;
  ```
- When the verb phrase is longer than `insert` (e.g. `insert or replace`),
  break after it so `into` starts its own river line and the river doesn't
  drift right:

  ```sql
  insert or replace
    into charstate
       ( char_name
       , name
       )
  values
       ( :char_name
       , :name
       ) returning *
         ;
  ```
- When the rows come from a `select` rather than a `values` block, the select
  continues the insert's river instead of nesting as a subquery would: there is
  no paren around it, so nothing forces an indent, and its clause keywords
  right-align into the same column as `into`. The semicolon lands in the
  content column, as it does after any other trailing clause:

  ```sql
  insert into note_links
            ( source_note_id
            , owner_id
            , target_note_id
            )
       select ?
            , ?
            , (
               select n.id
                 from notes n
                where n.owner_id = ?
                  and n.slug = ?
              )
              ;
  ```

  A subquery *inside* the select list still nests, because its paren is a real
  delimiter. Multi-row `values` (`values (1, 2), (3, 4)`) is not supported.
- `do nothing` takes the same river line `do update` would, with no `set`
  block after it.
- `returning` accepts a column list as well as `*`; both ride the values
  closing paren (`) returning id`).
- An `on conflict ... do update` upsert continues the same river. Unlike a plain
  insert (whose value block closes with `) ;` or `) returning *`), the value
  block closes on its own line, then `on conflict`, the conflict-target column
  block, and `do update` each take a river-aligned line. The `set` list is a
  leading-comma assignment list; each right-hand side drops to its own line
  under the column, and the trailing `;` sits in the content column:

  ```sql
  insert into save
            ( id
            , total_elapsed
            )
       values
            ( ?
            , ?
            )
  on conflict
            ( id
            )
    do update
          set total_elapsed
              = excluded.total_elapsed
            , last_real_time
              = excluded.last_real_time
              ;
  ```

## CTEs

A CTE is a `with` header (a named, leading-comma column list and an `as (`
opener) wrapping a body that is **the same recursive subquery block** as
everywhere else — it indents under its paren with its own independent river,
and its closing paren sits on its own line. After the close paren, the outer
statement (`update` / `select`) resumes as a normal top-level statement with
its own river, anchored at the left margin.

```sql
with current
   ( rowid
   , ts
   , end_time
   ) as (
        select rowid
             , ts
             , end_time
          from bugshields
         where end_time is null
      order by ts desc
         limit 1
     )
   update bugshields
      set end_time = time('now')
    where rowid = (select rowid from current)
returning *
          ;
```

- `with name` on the first line; the explicit column list uses the same
  leading-comma paren block as inserts.
- `) as (` closes the column list and opens the body on one line.
- The column list is optional: without one, the header collapses to
  `with <name> as (` on a single line and the body follows the same rule.
- The body follows the Subqueries rule exactly: own river, indented under the
  paren, closing paren on its own line. No special CTE body layout.
- The outer statement begins on the line after the close paren, formatted as
  a normal top-level statement (its own river, anchored at the left margin).

## Set operations

`union`, `union all`, `intersect`, and `except` join the river as whole
keywords — the entire operator right-aligns to the river column, the way
`order by` does, so a long operator widens the river for every arm:

```sql
   select a
     from t
union all
   select b
     from u
          ;
```

- The operator sits on a line of its own between the two arms.
- **All arms share one river**, computed across the operator and every arm's
  own clause keywords. The arms are not laid out independently; they line up
  as a single column so the operator reads as a divider between them.
- A chain of the *same* operator is flat — each arm at the same river, the
  operator repeated between them. Chains that **mix** operators are left
  unformatted (passed through): sqlite gives them left-associative
  precedence, and re-emitting them flat would assert a grouping the source
  did not have. Parenthesize to format them.
- The trailing `;` follows the usual rule, on its own line past the river.

This is what makes recursive CTEs expressible, since the recursive arm is
joined by `union all`:

```sql
with recursive reachable
             ( note_id
             , depth
             ) as (
                   select :root
                        , 0
                union all
                   select l.dst
                        , r.depth + 1
                     from note_links l
                     join reachable r
                       on l.src = r.note_id
               )
select note_id
     , depth
  from reachable
       ;
```

## Subqueries

A parenthesized `select` that forms a whole item — a derived table in `from`,
or a scalar in the select list or a values block — is formatted by
**recursing the river**: the inner query is laid out exactly as a top-level
query, with its own river computed from its own clauses, then the whole block
is shifted right so it nests under the parent.

There is no flattening: such a subquery **always breaks** onto its own lines,
regardless of length. One algorithm, no width threshold.

```sql
  select text
    from (
            select id
                 , text
              from lines
             where type = 'command'
               and character_name = ?
          order by id desc
             limit 500
         )
order by id asc
```

- The clause keyword holding the subquery (`from`, a select item) is emitted
  normally; the open paren trails it on the same line.
- The inner query starts on the next line. Its river is **independent** —
  computed from the inner query's own longest left-column item — and the
  whole inner block is indented so that river sits to the right of the parent
  content column. The inner query is therefore self-similar: read on its own,
  it is a correctly river-formatted statement.
- The closing paren sits on its own line, left-aligned to the inner query's
  river column.
- Nesting composes: a subquery inside a subquery applies the same rule again,
  each level shifting right relative to its parent.

This is the same mechanism a CTE body uses (see CTEs): one recursive block
rule for derived tables, scalars in the select list, insert values, and
`with ... as (...)` bodies.

A subquery that is part of a larger expression — a predicate operand such as
`in (...)`, `exists (...)` or `= (...)` — is not a block. It stays glued to
its expression on one line:

```sql
 where x in (select y from u)
   and exists (select 1 from v)
```

## Returning and semicolons

- `returning *` joins the river (it is usually the longest keyword, so it sits
  at the left margin of the statement).
- The terminating `;` goes on its own line, indented past the river into the
  content column:

  ```sql
  returning *
            ;
  ```
- Exception: when the statement ends with a closing paren, the paren and the
  semicolon share a line, on either side of the river:

  ```sql
            ) ;
  ```

## DDL (init.sql)

DDL uses a distinct convention. The canonical form, from `init.sql`:

```sql
create table if not exists
   skills (
char_name text
          not null
    ,tree text
          not null
    ,leaf text
  ,levels integer
          not null
   ,bonus integer
          not null
      ,ts datetime
          default current_timestamp
  ,unique (char_name, tree, leaf, bonus)
           on conflict ignore
        ) ;
```

- `create table if not exists` sits alone at the left margin; the table name
  right-aligns to the river on the next line.
- Column *names* are right-aligned to the river (so the type column lines
  up), with the leading comma glued directly to the name. The river width is
  the longest left-column item: column name (with comma), table name, or
  table-constraint keyword (`,primary key`) — whichever is longest.
- One level of indentation is a line with nothing on the left side of the
  river: constraints/defaults sit on lines that are blank up to the river,
  with content in the content column (`not null`, `default ...`).
- `primary key` / `foreign key` / `unique` table constraints join the same
  right-aligned column as the column names.
- Closing follows the DML rule: `) ;` across the river, paren right-aligned
  to the river column.
- `on conflict` under a table constraint indents one column further than
  other continuation lines (`on conflict ignore` under `unique` above).

## Statement separation

- Exactly one blank line between statements; no blank lines at the start of a
  file; one trailing newline at the end.
- Comment lines (`--`) belong to the statement they precede.

## Indexes and virtual tables

`create index` / `create unique index` put the name on the head line; `on` and
`where` right-align into a river set by the `create ... index` head:

```sql
create unique index notes_owner_slug
                 on notes(owner_id, slug)
              where deleted_at is null
                    ;

create index note_links_owner_target
          on note_links(owner_id, target_slug)
             ;
```

The river is **per statement**, as everywhere else. `create unique index` is
seven bytes longer than `create index`, so sibling indexes in the same file do
not line up with each other unless they agree on uniqueness. That is accepted:
making them agree would mean padding every plain index by seven columns, or
anchoring the river to something other than the statement head, and neither
earns its keep for a cosmetic gain.

`create virtual table` follows the same shape, with `using` on the river:

```sql
create virtual table notes_fts
               using fts5(title, body)
                     ;
```

The `using` argument list stays on one line, whatever its length.

## `without rowid`

`without rowid` takes its own river line below the closing paren, with the
semicolon on the line after — it does not glue to the closing `) ;`:

```sql
create table
 note_assets (
     note_id integer
             not null
   ,asset_id integer
             not null
,primary key (note_id, asset_id)
           )
without rowid
             ;
```

This follows `returning` and `on conflict`, which already take their own
river-aligned lines rather than riding the closing paren.

## Divergences from Holywell (sqlstyle.guide)

| Topic | Holywell | This style |
|---|---|---|
| Keyword case | UPPERCASE keywords | all lowercase |
| Builtin function / type case | as written | recognized builtins & type names lowercased; other idents as written |
| Commas | trailing, end of line | leading, own column |
| `AS` for column aliases | same line as expression | own continuation line below |
| `AS` for table aliases | required (`staff AS s1`) | omitted (`rooms r`) |
| Semicolon | end of last line | own line (usually) |
| River | keywords right-aligned, river after | same concept — this is the main point of agreement |
| DDL | left-aligned names, trailing commas | right-aligned names, glued leading commas |
| Table aliases | meaningful correlations | single letters (`r`, `m`) |
