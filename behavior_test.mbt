///|
fn album() -> String {
  "TITLE \"演示专辑\"\nPERFORMER \"MoonCue\"\nFILE \"album.wav\" WAVE\n  TRACK 01 AUDIO\n    TITLE \"Opening\"\n    INDEX 01 00:00:00\n  TRACK 02 AUDIO\n    TITLE \"Ending\"\n    INDEX 00 03:58:00\n    INDEX 01 04:00:00\n"
}

///|
fn has_error(text : String, code : String) -> Bool {
  @mooncue.parse(text).diagnostics.any(fn(d) {
    d.code == code && d.severity == "error"
  })
}

///|
test "75 CD frames per second, exact independent boundary values" {
  assert_eq(@mooncue.parse_time("00:00:74"), Ok(74))
  assert_eq(@mooncue.parse_time("00:01:00"), Ok(75))
  assert_eq(@mooncue.parse_time("01:00:00"), Ok(4500))
  assert_eq(@mooncue.parse_time("99:59:74"), Ok(449999))
  assert_eq(@mooncue.format_time(4500), Ok("01:00:00"))
}

///|
test "reject malformed or out of range timestamp" {
  for
    value in [
      "00:00:75", "00:60:00", "100:00:00", "1:00:00", "-1:00:00", "aa:00:00", "00:00",
      "00:00:00:00", " 00:00:00", "00:00:00 ",
    ] {
    assert_true(@mooncue.parse_time(value) is Err(_))
  }
  assert_true(@mooncue.format_time(-1) is Err(_))
  assert_true(@mooncue.format_time(450000) is Err(_))
}

///|
test "timestamp roundtrip across representable range" {
  for frame = 0; frame < 450000; frame = frame + 73 {
    match @mooncue.format_time(frame) {
      Ok(s) => assert_eq(@mooncue.parse_time(s), Ok(frame))
      Err(_) => fail("valid frame rejected")
    }
  }
}

///|
test "metadata, unicode and quoted filenames" {
  let r = @mooncue.parse(album())
  assert_true(r.is_valid())
  assert_eq(r.sheet.metadata.get("TITLE"), Some("演示专辑"))
  assert_eq(r.sheet.files[0].tracks[1].indexes[0].frames, 17850)
  assert_eq(r.sheet.files[0].tracks[1].indexes[1].frames, 18000)
}

///|
test "BOM CRLF tabs and case insensitive commands" {
  let r = @mooncue.parse(
    "\u{FEFF}file\t\"录音 文件.wav\" wave\r\n\ttrack 01 audio\r\nindex 01 00:00:00\r\n",
  )
  assert_true(r.is_valid())
  assert_eq(r.sheet.files[0].name, "录音 文件.wav")
  assert_eq(r.sheet.files[0].tracks[0].indexes[0].line, 3)
}

///|
test "Windows paths preserve backslashes" {
  let r = @mooncue.parse(
    "FILE \"C:\\Music\\album.wav\" WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00",
  )
  assert_true(r.is_valid())
  assert_eq(r.sheet.files[0].name, "C:\\Music\\album.wav")
}

///|
test "REM is freeform, including unmatched quotes" {
  let r = @mooncue.parse(
    "REM \"unfinished comment\n" + album() + "REM\tcomment \"\n",
  )
  assert_true(r.is_valid())
  assert_eq(r.sheet.remarks[0], "\"unfinished comment")
  assert_eq(r.sheet.files[0].tracks[1].remarks[0], "comment \"")
}

///|
test "quote syntax errors and recovery" {
  assert_true(
    has_error(
      "FILE \"missing WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00", "E_QUOTE",
    ),
  )
  assert_true(has_error("FILE \"x.wav\"WAVE", "E_QUOTE"))
  assert_true(has_error("FILE a\"b.wav WAVE", "E_QUOTE"))
}

///|
test "unknown commands stop normalization" {
  let source = album() + "MYSTERY 123\n"
  assert_true(has_error(source, "E_COMMAND"))
  assert_true(@mooncue.normalize(source) is Err(_))
}

///|
test "empty document and source file" {
  assert_true(has_error("", "E_EMPTY"))
  assert_true(has_error("REM comment", "E_EMPTY"))
  assert_true(has_error("FILE x.wav WAVE", "E_EMPTY_FILE"))
}

///|
test "command contexts" {
  assert_true(has_error("TRACK 01 AUDIO", "E_SCOPE"))
  assert_true(has_error("INDEX 01 00:00:00", "E_SCOPE"))
  assert_true(has_error("PREGAP 00:02:00", "E_SCOPE"))
  assert_true(has_error("FILE x.wav WAVE\nTITLE \"bad scope\"", "E_SCOPE"))
  assert_true(has_error(album() + "CATALOG 1234567890123", "E_SCOPE"))
}

///|
test "missing index one" {
  assert_true(
    has_error(
      "FILE x.wav WAVE\nTRACK 01 AUDIO\nINDEX 00 00:00:00", "E_MISSING_INDEX",
    ),
  )
}

///|
test "track number validation including overflow" {
  for n in ["00", "100", "-1", "x", "999999999999999999999999999"] {
    assert_true(
      has_error("FILE x.wav WAVE\nTRACK " + n + " AUDIO", "E_TRACK_NUMBER"),
    )
  }
}

///|
test "index numbers and ordering" {
  let head = "FILE x.wav WAVE\nTRACK 01 AUDIO\n"
  assert_true(has_error(head + "INDEX 100 00:00:00", "E_INDEX_NUMBER"))
  assert_true(has_error(head + "INDEX 02 00:00:00", "E_INDEX_ORDER"))
  assert_true(
    has_error(head + "INDEX 01 00:00:00\nINDEX 01 00:00:01", "E_INDEX_ORDER"),
  )
  assert_true(
    has_error(head + "INDEX 01 00:00:00\nINDEX 03 00:00:01", "E_INDEX_ORDER"),
  )
}

///|
test "timestamps cannot move backward within one file" {
  assert_true(
    has_error(
      "FILE x.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 02:00:00\nTRACK 02 AUDIO\nINDEX 01 01:00:00",
      "E_TIME_ORDER",
    ),
  )
}

///|
test "timestamps reset for each file, track numbers do not" {
  let r = @mooncue.parse(
    "FILE one.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 02:00:00\nFILE two.wav WAVE\nTRACK 02 AUDIO\nINDEX 01 00:00:00",
  )
  assert_true(r.is_valid())
  assert_true(
    has_error(
      "FILE one.wav WAVE\nTRACK 02 AUDIO\nINDEX 01 00:00:00\nFILE two.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00",
      "E_TRACK_ORDER",
    ),
  )
}

///|
test "duplicate metadata never silently overwritten" {
  let r = @mooncue.parse("TITLE first\nTITLE second\n" + album())
  assert_true(!r.is_valid())
  assert_eq(r.sheet.metadata.get("TITLE"), Some("first"))
}

///|
test "explicit audio profile and file kinds" {
  assert_true(
    has_error(
      "FILE x.bin BINARY\nTRACK 01 MODE1/2352\nINDEX 01 00:00:00", "E_MODE",
    ),
  )
  assert_true(
    has_error(
      "FILE x.flac FLAC\nTRACK 01 AUDIO\nINDEX 01 00:00:00", "E_FILE_TYPE",
    ),
  )
  // Common CUE convention: FLAC source is declared as WAVE.
  assert_true(
    @mooncue.parse("FILE x.flac WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00").is_valid(),
  )
}

///|
test "catalog ISRC FLAGS validation" {
  assert_true(
    @mooncue.parse(
      "CATALOG 1234567890123\nFILE x.wav WAVE\nTRACK 01 AUDIO\nISRC USABC2600001\nFLAGS DCP PRE\nINDEX 01 00:00:00",
    ).is_valid(),
  )
  assert_true(has_error("CATALOG 123\n" + album(), "E_CATALOG"))
  assert_true(has_error(album() + "ISRC BAD", "E_ISRC"))
  assert_true(has_error(album() + "FLAGS BAD", "E_FLAGS"))
}

///|
test "pregap postgap positioning" {
  assert_true(has_error(album() + "PREGAP 00:02:00", "E_ORDER"))
  assert_true(
    has_error(
      "FILE x.wav WAVE\nTRACK 01 AUDIO\nPOSTGAP 00:02:00\nINDEX 01 00:00:00", "E_ORDER",
    ),
  )
  assert_true(
    has_error(album() + "POSTGAP 00:02:00\nINDEX 02 05:00:00", "E_ORDER"),
  )
}

///|
test "error locations and multiple error collection" {
  let r = @mooncue.parse(
    "TITLE a\nTITLE b\nFILE x.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:60:00",
  )
  assert_true(
    r.diagnostics.any(fn(d) { d.code == "E_DUPLICATE" && d.line == 2 }),
  )
  assert_true(r.diagnostics.any(fn(d) { d.code == "E_TIME" && d.line == 5 }))
  assert_true(r.diagnostics.length() >= 3)
}

///|
test "malformed FILE never reuses previous file context" {
  let r = @mooncue.parse(
    album() + "FILE broken\nTRACK 03 AUDIO\nINDEX 01 05:00:00",
  )
  assert_true(!r.is_valid())
  assert_eq(r.sheet.files[0].tracks.length(), 2)
}

///|
test "malformed TRACK never appends indexes to previous track" {
  let r = @mooncue.parse(album() + "TRACK no AUDIO\nINDEX 02 05:00:00")
  assert_true(!r.is_valid())
  assert_eq(r.sheet.files[0].tracks[1].indexes.length(), 2)
}

///|
test "normalization is idempotent and preserves text" {
  match @mooncue.normalize(album()) {
    Ok(s) => {
      assert_eq(@mooncue.normalize(s), Ok(s))
      let a = @mooncue.parse(album()).sheet
      let b = @mooncue.parse(s).sheet
      assert_eq(a.metadata, b.metadata)
      assert_eq(a.files[0].name, b.files[0].name)
      assert_eq(a.files[0].tracks[1].metadata, b.files[0].tracks[1].metadata)
      assert_eq(
        a.files[0].tracks[1].indexes[1].frames,
        b.files[0].tracks[1].indexes[1].frames,
      )
    }
    Err(_) => fail("normalization failed")
  }
}

///|
test "exclude gap uses next INDEX 00 as previous end" {
  match @mooncue.plan(album(), Exclude, { "album.wav": 30000 }) {
    Ok(s) => {
      assert_eq(s.length(), 2)
      assert_eq(s[0].start_frame, 0)
      assert_eq(s[0].end_frame, Some(17850))
      assert_eq(s[1].start_frame, 18000)
      assert_eq(s[1].end_frame, Some(30000))
    }
    Err(_) => fail("plan failed")
  }
}

///|
test "append gap ends previous track at next INDEX 01" {
  match @mooncue.plan(album(), AppendPrevious, Map([])) {
    Ok(s) => {
      assert_eq(s[0].end_frame, Some(18000))
      assert_eq(s[1].start_frame, 18000)
      assert_eq(s[1].end_frame, None)
    }
    Err(_) => fail("plan failed")
  }
}

///|
test "prepend gap starts next track at INDEX 00" {
  match @mooncue.plan(album(), PrependNext, Map([])) {
    Ok(s) => {
      assert_eq(s[0].end_frame, Some(17850))
      assert_eq(s[1].start_frame, 17850)
    }
    Err(_) => fail("plan failed")
  }
}

///|
test "generated silence does not change source offsets" {
  let source = "FILE x.wav WAVE\nTRACK 01 AUDIO\nPREGAP 00:02:00\nINDEX 00 00:00:00\nINDEX 01 00:01:00\nPOSTGAP 00:03:00"
  assert_true(@mooncue.parse(source).is_valid())
  match @mooncue.plan(source, PrependNext, { "x.wav": 750 }) {
    Ok(s) => {
      assert_eq(s[0].start_frame, 0)
      assert_eq(s[0].end_frame, Some(750))
      assert_eq(s[0].generated_pregap_frames, 150)
      assert_eq(s[0].generated_postgap_frames, 225)
    }
    Err(_) => fail("plan failed")
  }
}

///|
test "file-local ends never borrow timestamps from next file" {
  let source = "FILE a.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00\nFILE b.wav WAVE\nTRACK 02 AUDIO\nINDEX 01 00:00:00"
  match @mooncue.plan(source, Exclude, { "a.wav": 1000 }) {
    Ok(s) => {
      assert_eq(s[0].end_frame, Some(1000))
      assert_eq(s[1].end_frame, None)
    }
    Err(_) => fail("plan failed")
  }
}

///|
test "invalid duration or unknown file rejected" {
  for
    lengths in [
      { "album.wav": 0 },
      { "album.wav": -1 },
      { "album.wav": 18000 },
      { "other.wav": 50000 },
    ] {
    assert_true(@mooncue.plan(album(), Exclude, lengths) is Err(_))
  }
}

///|
test "invalid source does not produce partial plan" {
  assert_true(@mooncue.plan(album() + "UNKNOWN x", Exclude, Map([])) is Err(_))
}

///|
test "zero length segment rejected" {
  let source = "FILE x.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00\nTRACK 02 AUDIO\nINDEX 01 00:00:00"
  assert_true(@mooncue.plan(source, Exclude, Map([])) is Err(_))
}

///|
test "raw disc image planning explicitly unsupported" {
  let source = "FILE x.bin BINARY\nTRACK 01 AUDIO\nINDEX 01 00:00:00"
  assert_true(@mooncue.parse(source).is_valid())
  assert_true(@mooncue.plan(source, Exclude, Map([])) is Err(_))
}

///|
test "unexpected control characters rejected" {
  assert_true(has_error("TITLE \"a\u{0000}b\"\n" + album(), "E_CONTROL"))
}

///|
test "bounded deterministic malformed-input fuzz never panics" {
  let alphabet = "FILE TRACK INDEX REM \"\t\n\r01239:中文".to_array()
  let mut state = 17U
  for _ in 0..<600 {
    let buf : Array[Char] = []
    for _ in 0..<80 {
      state = state * 1664525U + 1013904223U
      buf.push(
        alphabet[(state % alphabet.length().reinterpret_as_uint()).reinterpret_as_int()],
      )
    }
    let source = String::from_array(buf)
    ignore(@mooncue.parse(source))
    ignore(@mooncue.normalize(source))
  }
}
