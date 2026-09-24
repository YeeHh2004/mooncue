///|
fn lead_in_cue() -> String {
  "FILE a.wav WAVE\nTRACK 01 AUDIO\nINDEX 00 00:00:00\nINDEX 01 00:02:00\nTRACK 02 AUDIO\nINDEX 00 01:00:00\nINDEX 01 01:02:00"
}

///|
test "audit proves known source partition with excluded lead-in and gap" {
  match @mooncue.audit_plan(lead_in_cue(), Exclude, { "a.wav": 9000 }) {
    Ok(a) => {
      assert_true(a.complete)
      assert_eq(a.sources[0].selected_frames, Some(8700))
      assert_eq(a.sources[0].known_omitted_frames, 300)
      assert_eq(a.sources[0].omitted.length(), 2)
      assert_eq(a.sources[0].omitted[0].start_frame, 0)
      assert_eq(a.sources[0].omitted[0].end_frame, 150)
      assert_eq(a.sources[0].omitted[1].start_frame, 4500)
      assert_eq(a.sources[0].omitted[1].end_frame, 4650)
    }
    Err(_) => fail("audit failed")
  }
}

///|
test "append retains intertrack gap but not first-track lead-in" {
  match @mooncue.audit_plan(lead_in_cue(), AppendPrevious, { "a.wav": 9000 }) {
    Ok(a) => {
      assert_eq(a.sources[0].selected_frames, Some(8850))
      assert_eq(a.sources[0].known_omitted_frames, 150)
    }
    Err(_) => fail("audit failed")
  }
}

///|
test "prepend includes all indexed lead-in audio" {
  match @mooncue.audit_plan(lead_in_cue(), PrependNext, { "a.wav": 9000 }) {
    Ok(a) => {
      assert_eq(a.sources[0].selected_frames, Some(9000))
      assert_eq(a.sources[0].omitted.length(), 0)
    }
    Err(_) => fail("audit failed")
  }
}

///|
test "unknown media end never claims complete coverage" {
  match @mooncue.audit_plan(lead_in_cue(), Exclude, Map([])) {
    Ok(a) => {
      assert_true(!a.complete)
      assert_eq(a.sources[0].selected_frames, None)
      assert_eq(a.sources[0].known_omitted_frames, 300)
    }
    Err(_) => fail("audit failed")
  }
}

///|
test "coverage distinguishes repeated FILE declarations" {
  let cue = "FILE a.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00\nFILE a.wav WAVE\nTRACK 02 AUDIO\nINDEX 01 00:01:00"
  match @mooncue.audit_plan(cue, Exclude, { "a.wav": 750 }) {
    Ok(a) => {
      assert_eq(a.sources[0].selected_frames, Some(750))
      assert_eq(a.sources[1].selected_frames, Some(675))
      assert_eq(a.sources[1].source_number, 2)
    }
    Err(_) => fail("audit failed")
  }
  assert_true(@mooncue.audit_plan(cue, Exclude, { "a.wav": 50 }) is Err(_))
}
