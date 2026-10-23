///|
test "emit: select river layout" {
  inspect(
    @sqlbrook.format(
      "select a, b, c from t where x = 1 order by ts desc limit 1;",
    ).output,
    content=(
      #|  select a
      #|       , b
      #|       , c
      #|    from t
      #|   where x = 1
      #|order by ts desc
      #|   limit 1
      #|         ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format("select a from t").output,
    content=(
      #|select a
      #|  from t
      #|
    ),
  )
}

///|
test "emit: as on its own line, river-aligned" {
  inspect(
    @sqlbrook.format(
      "select printf('%-18s', short_name) as short_name, full_name as f from t;",
    ).output,
    content=(
      #|select printf('%-18s', short_name)
      #|    as short_name
      #|     , full_name
      #|    as f
      #|  from t
      #|       ;
      #|
    ),
  )
}

///|
test "emit: predicates one per line, and/or in the river" {
  inspect(
    @sqlbrook.format(
      "select a from t where x = :x and y like '%' || :term || '%' or z is not null;",
    ).output,
    content=(
      #|select a
      #|  from t
      #| where x = :x
      #|   and y like '%' || :term || '%'
      #|    or z is not null
      #|       ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format("select a from t where x between 1 and 2 and y = 3;").output,
    content=(
      #|select a
      #|  from t
      #| where x between 1 and 2
      #|   and y = 3
      #|       ;
      #|
    ),
  )
}

///|
test "emit: having joins the river, and/or split like where" {
  inspect(
    @sqlbrook.format(
      "select user_id, count(*) as n from events group by user_id having count(*) > 5 and sum(amount) < 100;",
    ).output,
    content=(
      #|  select user_id
      #|       , count(*)
      #|      as n
      #|    from events
      #|group by user_id
      #|  having count(*) > 5
      #|     and sum(amount) < 100
      #|         ;
      #|
    ),
  )
}

///|
test "emit: case expressions stay inline" {
  inspect(
    @sqlbrook.format("select case when x = 1 then 2 else 3 end as y from t;").output,
    content=(
      #|select case when x = 1 then 2 else 3 end
      #|    as y
      #|  from t
      #|       ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format(
      "select a from t where case when x > 1 and y > 2 then 1 else 0 end = 1 and z = 3;",
    ).output,
    content=(
      #|select a
      #|  from t
      #| where case when x > 1 and y > 2 then 1 else 0 end = 1
      #|   and z = 3
      #|       ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format(
      "select a from t where case when x between 1 and 2 then 1 else 0 end = 1 and z = 3;",
    ).output,
    content=(
      #|select a
      #|  from t
      #| where case when x between 1 and 2 then 1 else 0 end = 1
      #|   and z = 3
      #|       ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format(
      "select a from t order by case s when 'a' then 1 else 2 end desc;",
    ).output,
    content=(
      #|  select a
      #|    from t
      #|order by case s when 'a' then 1 else 2 end desc
      #|         ;
      #|
    ),
  )
}

///|
test "emit: joins set the river, on gets its own line" {
  inspect(
    @sqlbrook.format(
      "select r.room_id, m.filename from rooms r inner join maps m on r.map_id = m.map_id where r.room_id = :room_id;",
    ).output,
    content=(
      #|    select r.room_id
      #|         , m.filename
      #|      from rooms r
      #|inner join maps m
      #|        on r.map_id = m.map_id
      #|     where r.room_id = :room_id
      #|           ;
      #|
    ),
  )
}

///|
test "emit: subquery recurses the river (golden: history query)" {
  inspect(
    @sqlbrook.format(
      "select text from (select id, text from lines where type = 'command' and character_name = ? order by id desc limit 500) order by id asc",
    ).output,
    content=(
      #|  select text
      #|    from (
      #|            select id
      #|                 , text
      #|              from lines
      #|             where type = 'command'
      #|               and character_name = ?
      #|          order by id desc
      #|             limit 500
      #|         )
      #|order by id asc
      #|
    ),
  )
}

///|
test "emit: scalar subqueries in the select list keep their aliases" {
  inspect(
    @sqlbrook.format(
      "select (select count(*) from sessions) as total, (select count(*) from sessions where ts > :since) as recent;",
    ).output,
    content=(
      #|select (
      #|        select count(*)
      #|          from sessions
      #|       )
      #|    as total
      #|     , (
      #|        select count(*)
      #|          from sessions
      #|         where ts > :since
      #|       )
      #|    as recent
      #|       ;
      #|
    ),
  )
}

///|
test "emit: nested subqueries shift right level by level" {
  inspect(
    @sqlbrook.format(
      "select a from (select a from (select a, b from t where b > 1) where a < 5)",
    ).output,
    content=(
      #|select a
      #|  from (
      #|        select a
      #|          from (
      #|                select a
      #|                     , b
      #|                  from t
      #|                 where b > 1
      #|               )
      #|         where a < 5
      #|       )
      #|
    ),
  )
}

///|
test "emit: builtin functions and type names are lowercased" {
  inspect(
    @sqlbrook.format(
      "select MAX(x), COUNT(*), Coalesce(a, b), MyFunc(z) from t;",
    ).output,
    content=(
      #|select max(x)
      #|     , count(*)
      #|     , coalesce(a, b)
      #|     , MyFunc(z)
      #|  from t
      #|       ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format("create table t (a TEXT, b Integer, c VARCHAR);").output,
    content=(
      #|create table
      #| t (
      #| a text
      #|,b integer
      #|,c varchar
      #| ) ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format("select Max from t;").output,
    content=(
      #|select Max
      #|  from t
      #|       ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format("select DATETIME('now') from t;").output,
    content=(
      #|select datetime('now')
      #|  from t
      #|       ;
      #|
    ),
  )
}

///|
test "emit: function calls and predicate subqueries are not blocks" {
  inspect(
    @sqlbrook.format("select count(*) from t;").output,
    content=(
      #|select count(*)
      #|  from t
      #|       ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format("select a from t where x in (select x from u);").output,
    content=(
      #|select a
      #|  from t
      #| where x in (select x from u)
      #|       ;
      #|
    ),
  )
}

///|
test "emit: cte is the same recursive block (golden: bugshield close)" {
  inspect(
    @sqlbrook.format(
      "with current (rowid, ts, end_time) as (select rowid, ts, end_time from bugshields where end_time is null order by ts desc limit 1) update bugshields set end_time = time('now') where rowid = (select rowid from current) returning *;",
    ).output,
    content=(
      #|with current
      #|   ( rowid
      #|   , ts
      #|   , end_time
      #|   ) as (
      #|        select rowid
      #|             , ts
      #|             , end_time
      #|          from bugshields
      #|         where end_time is null
      #|      order by ts desc
      #|         limit 1
      #|     )
      #|   update bugshields
      #|      set end_time = time('now')
      #|    where rowid = (select rowid from current)
      #|returning *
      #|          ;
      #|
    ),
  )
}

///|
test "emit: with recursive carries the modifier, column block follows" {
  inspect(
    @sqlbrook.format(
      "with recursive reachable (note_id, depth) as (select l.dst, 1 from note_links l where l.src = :root) select note_id, depth from reachable order by depth;",
    ).output,
    content=(
      #|with recursive reachable
      #|             ( note_id
      #|             , depth
      #|             ) as (
      #|                select l.dst
      #|                     , 1
      #|                  from note_links l
      #|                 where l.src = :root
      #|               )
      #|  select note_id
      #|       , depth
      #|    from reachable
      #|order by depth
      #|         ;
      #|
    ),
  )
}

///|
test "emit: create table right-aligns names, glues leading commas" {
  inspect(
    @sqlbrook.format(
      "create table if not exists skills (char_name text not null, tree text not null, leaf text, ts datetime default current_timestamp, unique (char_name, tree, leaf) on conflict ignore);",
    ).output,
    content=(
      #|create table if not exists
      #|   skills (
      #|char_name text
      #|          not null
      #|    ,tree text
      #|          not null
      #|    ,leaf text
      #|      ,ts datetime
      #|          default current_timestamp
      #|  ,unique (char_name, tree, leaf)
      #|           on conflict ignore
      #|        ) ;
      #|
    ),
  )
}

///|
test "emit: table name wider than columns sets the river" {
  inspect(
    @sqlbrook.format(
      "create table if not exists world.flyable_npcs (full_name text, area text, note text);",
    ).output,
    content=(
      #|create table if not exists
      #|world.flyable_npcs (
      #|         full_name text
      #|             ,area text
      #|             ,note text
      #|                 ) ;
      #|
    ),
  )
}

///|
test "emit: foreign key constraint, references on the content column" {
  inspect(
    @sqlbrook.format(
      "create table if not exists logs (char_name text, primary key (char_name, ts), foreign key (char_state) references vitals(rowid));",
    ).output,
    content=(
      #|create table if not exists
      #|        logs (
      #|   char_name text
      #|,primary key (char_name, ts)
      #|,foreign key (char_state)
      #|             references vitals(rowid)
      #|           ) ;
      #|
    ),
  )
}

///|
test "emit: create view header, as line, body laid out as a select" {
  inspect(
    @sqlbrook.format(
      "create view if not exists world.npcs_fmt as select printf('%-18s', short_name) as short_name, area from flyable_npcs;",
    ).output,
    content=(
      #|create view if not exists world.npcs_fmt
      #|    as
      #|select printf('%-18s', short_name)
      #|    as short_name
      #|     , area
      #|  from flyable_npcs
      #|       ;
      #|
    ),
  )
}

///|
test "emit: insert with no column list keeps values aligned" {
  inspect(
    @sqlbrook.format(
      "insert into world.maps values (:map_id, :filename, :domain);",
    ).output,
    content=(
      #|insert into world.maps
      #|     values
      #|          ( :map_id
      #|          , :filename
      #|          , :domain
      #|          ) ;
      #|
    ),
  )
}

///|
test "emit: upsert_save (on conflict do update)" {
  inspect(
    @sqlbrook.format(
      "insert into save (id, total_elapsed, last_realized_elapsed, last_real_time) values (?, ?, ?, ?) on conflict (id) do update set total_elapsed = excluded.total_elapsed, last_realized_elapsed = excluded.last_realized_elapsed, last_real_time = excluded.last_real_time;",
    ).output,
    content=(
      #|insert into save
      #|          ( id
      #|          , total_elapsed
      #|          , last_realized_elapsed
      #|          , last_real_time
      #|          )
      #|     values
      #|          ( ?
      #|          , ?
      #|          , ?
      #|          , ?
      #|          )
      #|on conflict
      #|          ( id
      #|          )
      #|  do update
      #|        set total_elapsed
      #|            = excluded.total_elapsed
      #|          , last_realized_elapsed
      #|            = excluded.last_realized_elapsed
      #|          , last_real_time
      #|            = excluded.last_real_time
      #|            ;
      #|
    ),
  )
}

///|
test "emit: upsert_force (on conflict do update)" {
  inspect(
    @sqlbrook.format(
      "insert into force (save_id, id, origin, magnitude, standing, pool) values (?, ?, ?, ?, ?, ?) on conflict (save_id, id) do update set origin = excluded.origin, magnitude = excluded.magnitude, standing = excluded.standing, pool = excluded.pool;",
    ).output,
    content=(
      #|insert into force
      #|          ( save_id
      #|          , id
      #|          , origin
      #|          , magnitude
      #|          , standing
      #|          , pool
      #|          )
      #|     values
      #|          ( ?
      #|          , ?
      #|          , ?
      #|          , ?
      #|          , ?
      #|          , ?
      #|          )
      #|on conflict
      #|          ( save_id
      #|          , id
      #|          )
      #|  do update
      #|        set origin
      #|            = excluded.origin
      #|          , magnitude
      #|            = excluded.magnitude
      #|          , standing
      #|            = excluded.standing
      #|          , pool
      #|            = excluded.pool
      #|            ;
      #|
    ),
  )
}

///|
test "emit: comments precede the statement unchanged" {
  inspect(
    @sqlbrook.format("--name: find\n--fn: first\nselect a from t;").output,
    content=(
      #|--name: find
      #|--fn: first
      #|select a
      #|  from t
      #|       ;
      #|
    ),
  )
}

///|
test "emit: set operations join the river as whole keywords" {
  inspect(
    @sqlbrook.format("select a from t union all select b from u;").output,
    content=(
      #|   select a
      #|     from t
      #|union all
      #|   select b
      #|     from u
      #|          ;
      #|
    ),
  )
}

///|
test "emit: bare union / intersect / except" {
  inspect(
    @sqlbrook.format("select a from t union select b from u;").output,
    content=(
      #|select a
      #|  from t
      #| union
      #|select b
      #|  from u
      #|       ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format("select a from t intersect select b from u;").output,
    content=(
      #|   select a
      #|     from t
      #|intersect
      #|   select b
      #|     from u
      #|          ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format("select a from t except select b from u;").output,
    content=(
      #|select a
      #|  from t
      #|except
      #|select b
      #|  from u
      #|       ;
      #|
    ),
  )
}

///|
test "emit: recursive CTE body with union all" {
  inspect(
    @sqlbrook.format(
      "with recursive reachable (note_id, depth) as (select :root, 0 union all select l.dst, r.depth + 1 from note_links l join reachable r on l.src = r.note_id) select note_id, depth from reachable;",
    ).output,
    content=(
      #|with recursive reachable
      #|             ( note_id
      #|             , depth
      #|             ) as (
      #|                   select :root
      #|                        , 0
      #|                union all
      #|                   select l.dst
      #|                        , r.depth + 1
      #|                     from note_links l
      #|                     join reachable r
      #|                       on l.src = r.note_id
      #|               )
      #|select note_id
      #|     , depth
      #|  from reachable
      #|       ;
      #|
    ),
  )
}

///|
test "emit: a chain of one operator flattens" {
  inspect(
    @sqlbrook.format(
      "select a from t union select b from u union select c from v;",
    ).output,
    content=(
      #|select a
      #|  from t
      #| union
      #|select b
      #|  from u
      #| union
      #|select c
      #|  from v
      #|       ;
      #|
    ),
  )
}

///|
test "emit: create index, own river per statement" {
  inspect(
    @sqlbrook.format(
      "create index note_links_owner_target on note_links (owner_id, target_slug);",
    ).output,
    content=(
      #|create index note_links_owner_target
      #|          on note_links(owner_id, target_slug)
      #|             ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format(
      "create unique index notes_owner_slug on notes (owner_id, slug) where deleted_at is null;",
    ).output,
    content=(
      #|create unique index notes_owner_slug
      #|                 on notes(owner_id, slug)
      #|              where deleted_at is null
      #|                    ;
      #|
    ),
  )
}

///|
test "emit: create table ... without rowid takes its own river line" {
  inspect(
    @sqlbrook.format(
      "create table note_assets (note_id integer not null, asset_id integer not null, primary key (note_id, asset_id)) without rowid;",
    ).output,
    content=(
      #|create table
      #| note_assets (
      #|     note_id integer
      #|             not null
      #|   ,asset_id integer
      #|             not null
      #|,primary key (note_id, asset_id)
      #|           )
      #|without rowid
      #|             ;
      #|
    ),
  )
}

///|
test "emit: create virtual table using fts5" {
  inspect(
    @sqlbrook.format("create virtual table notes_fts using fts5 (title, body);").output,
    content=(
      #|create virtual table notes_fts
      #|               using fts5(title, body)
      #|                     ;
      #|
    ),
  )
}

///|
test "emit: insert or ignore takes the multi-word verb shape" {
  inspect(
    @sqlbrook.format(
      "insert or ignore into note_links (source_note_id, target_slug) values (:src, :slug);",
    ).output,
    content=(
      #|insert or ignore
      #|  into note_links
      #|     ( source_note_id
      #|     , target_slug
      #|     )
      #|values
      #|     ( :src
      #|     , :slug
      #|     ) ;
      #|
    ),
  )
}

///|
test "emit: delete is an ordinary clause sequence" {
  inspect(
    @sqlbrook.format(
      "delete from note_links where source_note_id = ? and owner_id = ?;",
    ).output,
    content=(
      #|delete
      #|  from note_links
      #| where source_note_id = ?
      #|   and owner_id = ?
      #|       ;
      #|
    ),
  )
}

///|
test "emit: on conflict do nothing" {
  inspect(
    @sqlbrook.format(
      "insert into content (hash, title, body) values (?, ?, ?) on conflict (hash) do nothing;",
    ).output,
    content=(
      #|insert into content
      #|          ( hash
      #|          , title
      #|          , body
      #|          )
      #|     values
      #|          ( ?
      #|          , ?
      #|          , ?
      #|          )
      #|on conflict
      #|          ( hash
      #|          )
      #| do nothing
      #|            ;
      #|
    ),
  )
}

///|
test "emit: returning with an explicit column list" {
  inspect(
    @sqlbrook.format(
      "insert into notes (owner_id, slug) values (?, ?) returning id;",
    ).output,
    content=(
      #|insert into notes
      #|          ( owner_id
      #|          , slug
      #|          )
      #|     values
      #|          ( ?
      #|          , ?
      #|          ) returning id
      #|            ;
      #|
    ),
  )
  inspect(
    @sqlbrook.format(
      "insert into notes (owner_id, slug) values (?, ?) returning id, slug;",
    ).output,
    content=(
      #|insert into notes
      #|          ( owner_id
      #|          , slug
      #|          )
      #|     values
      #|          ( ?
      #|          , ?
      #|          ) returning id, slug
      #|            ;
      #|
    ),
  )
}

///|
test "emit: insert from select continues the insert's river" {
  inspect(
    @sqlbrook.format(
      "insert into note_links (source_note_id, owner_id) select ?, ?;",
    ).output,
    content=(
      #|insert into note_links
      #|          ( source_note_id
      #|          , owner_id
      #|          )
      #|     select ?
      #|          , ?
      #|            ;
      #|
    ),
  )
}

///|
test "emit: insert from select with a correlated subquery" {
  inspect(
    @sqlbrook.format(
      "insert into note_links (source_note_id, owner_id, target_slug, context, target_note_id) select ?, ?, ?, ?, (select n.id from notes n where n.owner_id = ? and n.slug = ? and n.deleted_at is null);",
    ).output,
    content=(
      #|insert into note_links
      #|          ( source_note_id
      #|          , owner_id
      #|          , target_slug
      #|          , context
      #|          , target_note_id
      #|          )
      #|     select ?
      #|          , ?
      #|          , ?
      #|          , ?
      #|          , (
      #|             select n.id
      #|               from notes n
      #|              where n.owner_id = ?
      #|                and n.slug = ?
      #|                and n.deleted_at is null
      #|            )
      #|            ;
      #|
    ),
  )
}

///|
test "emit: leading newline absorbed (embedded-query convention)" {
  let bare = @sqlbrook.format("select a, b from t where x = :x;").output
  let lead = @sqlbrook.format("\nselect a, b from t where x = :x;\n").output
  assert_eq(bare, lead)
  assert_true(lead[0] != ' ')
}

///|
test "emit: stray case keywords outside a case are unsupported" {
  let r = @sqlbrook.format("select end from t;")
  assert_true(r.had_passthrough())
  debug_inspect(
    r.skips,
    content=(
      #|[{ kind: "select", line: 1 }]
    ),
  )
}

///|
test "passthrough: unsupported construct emitted unchanged" {
  let src = "select rank() over (order by xp) from t ;\n"
  let r = @sqlbrook.format(src)
  assert_true(r.had_passthrough())
  assert_eq(r.output, src)
}

///|
test "passthrough: mixed set operators are not regrouped" {
  let src = "select a from t union select b from u union all select c from v ;\n"
  let r = @sqlbrook.format(src)
  assert_true(r.had_passthrough())
  assert_eq(r.output, src)
}

///|
test "passthrough: multi-row values is a deliberate gap" {
  let r = @sqlbrook.format("insert into t (a, b) values (1, 2), (3, 4);")
  assert_true(r.had_passthrough())
  inspect(
    r.output,
    content=(
      #|insert into t (a, b) values (1, 2), (3, 4);
      #|
    ),
  )
}

///|
test "passthrough: skips report kind and 1-based line" {
  let r = @sqlbrook.format("select 1;\n\n-- note\nvacuum;\n\nselect é from t;")
  assert_eq(r.skips.length(), 1)
  assert_eq(r.skips[0].kind, "vacuum")
  assert_eq(r.skips[0].line, 3)
}

///|
test "passthrough: passed-through statements keep their leading comments once" {
  inspect(
    @sqlbrook.format("--name: x\nvacuum;").output,
    content=(
      #|--name: x
      #|vacuum;
      #|
    ),
  )
}
