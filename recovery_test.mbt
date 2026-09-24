///|
test "unclosed FILE quote resets both file and track scope" {
  let input = "FILE first.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00\nFILE \"broken\nTRACK 02 AUDIO\nINDEX 01 02:00:00"
  let r = @mooncue.parse(input)
  assert_eq(r.sheet.files.length(), 1)
  assert_eq(r.sheet.files[0].tracks.length(), 1)
  assert_eq(r.sheet.files[0].tracks[0].indexes.length(), 1)
  assert_true(r.diagnostics.any(fn(d) { d.code == "E_QUOTE" && d.line == 4 }))
  assert_true(r.diagnostics.any(fn(d) { d.code == "E_SCOPE" && d.line == 5 }))
}

///|
test "unclosed TRACK quote never mutates previous track metadata or indexes" {
  let input = "FILE a.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00\nTRACK \"bad\nTITLE accidental\nINDEX 02 01:00:00\nTRACK 02 AUDIO\nINDEX 01 02:00:00"
  let r = @mooncue.parse(input)
  assert_true(!r.is_valid())
  assert_eq(r.sheet.files[0].tracks[0].metadata.get("TITLE"), None)
  assert_eq(r.sheet.files[0].tracks[0].indexes.length(), 1)
  assert_eq(r.sheet.files[0].tracks[1].indexes[0].frames, 9000)
}

///|
test "control-corrupted boundary resets stale context" {
  let r = @mooncue.parse(
    "FILE a.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00\nTRACK \u{0000}02 AUDIO\nINDEX 02 01:00:00",
  )
  assert_true(!r.is_valid())
  assert_eq(r.sheet.files[0].tracks[0].indexes.length(), 1)
}
