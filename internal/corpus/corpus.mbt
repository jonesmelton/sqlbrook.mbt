///|
/// Every golden SQL file as `(file name, contents)`. The files are copies of
/// the reference implementation's examples; `scripts/sync_corpus.mbtx`
/// refreshes them.
pub fn all() -> Array[(String, String)] {
  [
    ("bugshield.sql", bugshield),
    ("char.sql", char),
    ("init.sql", init),
    ("items.sql", items),
    ("lore.sql", lore),
    ("map.sql", map),
    ("session.sql", session),
    ("vitals.sql", vitals),
  ]
}
