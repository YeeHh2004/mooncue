///|
test "catalog applies album performer but not album title to tracks" {
  let cue = "TITLE Album\nPERFORMER Ensemble\nSONGWRITER Author\nFILE a.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00\nTRACK 02 AUDIO\nTITLE Solo\nPERFORMER Soloist\nINDEX 00 01:00:00\nINDEX 01 01:02:00"
  match @mooncue.catalog(cue) {
    Ok(tracks) => {
      assert_eq(tracks[0].title, "Track 01")
      assert_eq(tracks[0].performer, "Ensemble")
      assert_eq(tracks[1].title, "Solo")
      assert_eq(tracks[1].performer, "Soloist")
      assert_eq(tracks[1].songwriter, "Author")
      assert_eq(tracks[1].start_frame, 4650)
      assert_eq(tracks[1].line, 7)
    }
    Err(_) => fail("catalog rejected valid CUE")
  }
}

///|
test "catalog preserves multifile positions and explicit empty overrides" {
  let cue = "PERFORMER Album\nFILE a.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 01:00:00\nFILE b.wav WAVE\nTRACK 02 AUDIO\nPERFORMER \"\"\nINDEX 01 00:00:00"
  match @mooncue.catalog(cue) {
    Ok(tracks) => {
      assert_eq(tracks[0].start_frame, 4500)
      assert_eq(tracks[1].file, "b.wav")
      assert_eq(tracks[1].start_frame, 0)
      assert_eq(tracks[1].performer, "")
      assert_eq(tracks[1].songwriter, "")
    }
    Err(_) => fail("catalog rejected valid CUE")
  }
}

///|
test "catalog refuses partial data from invalid documents" {
  assert_true(@mooncue.catalog("FILE a.wav WAVE\nTRACK 01 AUDIO") is Err(_))
}
