///|
/// CUE quoting does not use backslash escapes: Windows paths remain literal.
fn tokens(line : String) -> Result[Array[String], String] {
  let out : Array[String] = []
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == ' ' || chars[i] == '\t' {
      i += 1
      continue
    }
    let buf : Array[Char] = []
    if chars[i] == '"' {
      i += 1
      while i < chars.length() && chars[i] != '"' {
        buf.push(chars[i])
        i += 1
      }
      if i == chars.length() {
        return Err("unterminated quoted value")
      }
      i += 1
      if i < chars.length() && chars[i] != ' ' && chars[i] != '\t' {
        return Err("expected whitespace after closing quote")
      }
    } else {
      while i < chars.length() && chars[i] != ' ' && chars[i] != '\t' {
        if chars[i] == '"' {
          return Err("quote must start a token")
        }
        buf.push(chars[i])
        i += 1
      }
    }
    out.push(String::from_array(buf))
  }
  Ok(out)
}

///|
fn put_metadata(
  meta : Map[String, String],
  key : String,
  value : String,
  line : Int,
  ds : Array[Diagnostic],
) -> Unit {
  if meta.contains(key) {
    error(ds, "E_DUPLICATE", line, "duplicate " + key)
  } else {
    meta[key] = value
  }
}

///|
/// Parse the documented audio CUE profile; unsupported commands are errors.
pub fn parse(text : String) -> Report {
  let sheet : Sheet = { metadata: Map([]), remarks: [], files: [] }
  let ds : Array[Diagnostic] = []
  let mut file : CueFile? = None
  let mut track : Track? = None
  let mut line_no = 0
  for raw in text.split("\n") {
    line_no += 1
    let line = (if line_no == 1 {
        raw.to_owned().trim_start(chars="\u{FEFF}").to_owned()
      } else {
        raw.to_owned()
      })
      .trim()
      .to_owned()
    if line.is_empty() {
      continue
    }
    // Recover scope before tokenization: malformed quoted FILE/TRACK lines
    // must not let subsequent indexes leak into the previous valid track.
    let head = line
      .iter()
      .take_while(fn(c) { !c.is_ascii_whitespace() })
      .collect()
    let command_head = String::from_array(head).to_upper()
    if command_head == "FILE" {
      file = None
      track = None
    } else if command_head == "TRACK" {
      track = None
    }
    if line.any(fn(c) { c.is_control() && c != '\t' }) {
      error(ds, "E_CONTROL", line_no, "unexpected control character")
      continue
    }
    // REM is free-form text, including unmatched quotes.
    let rem_head = line.length() >= 3 && line[:3].to_owned().to_upper() == "REM"
    if rem_head &&
      (
        line.length() == 3 ||
        line.get_char(3) == Some(' ') ||
        line.get_char(3) == Some('\t')
      ) {
      let value = line[3:].to_owned().trim().to_owned()
      match track {
        Some(t) => t.remarks.push(value)
        None => sheet.remarks.push(value)
      }
      continue
    }
    let parts = match tokens(line) {
      Err(message) => {
        error(ds, "E_QUOTE", line_no, message)
        continue
      }
      Ok(p) => p
    }
    if parts.is_empty() {
      continue
    }
    let command = parts[0].to_upper()
    let expected = match command {
      "FILE" | "TRACK" | "INDEX" => 3
      "TITLE"
      | "PERFORMER"
      | "SONGWRITER"
      | "CATALOG"
      | "CDTEXTFILE"
      | "ISRC"
      | "PREGAP"
      | "POSTGAP" => 2
      "FLAGS" => -1
      _ => {
        error(ds, "E_COMMAND", line_no, "unsupported command: " + command)
        continue
      }
    }
    if (expected >= 0 && parts.length() != expected) ||
      (expected == -1 && parts.length() < 2) {
      error(ds, "E_ARGUMENTS", line_no, "invalid argument count for " + command)
      continue
    }
    match command {
      "FILE" => {
        if parts[1].is_empty() {
          error(ds, "E_FILE_NAME", line_no, "empty source filename")
          continue
        }
        let f : CueFile = {
          name: parts[1],
          kind: parts[2].to_upper(),
          line: line_no,
          tracks: [],
        }
        if !["WAVE", "MP3", "AIFF", "BINARY", "MOTOROLA"].contains(f.kind) {
          error(ds, "E_FILE_TYPE", line_no, "unsupported FILE type: " + f.kind)
        }
        sheet.files.push(f)
        file = Some(f)
      }
      "TRACK" => {
        let f = match file {
          Some(f) => f
          None => {
            error(ds, "E_SCOPE", line_no, "TRACK requires a FILE")
            continue
          }
        }
        let n = match decimal(parts[1], 99) {
          Some(n) if n > 0 => n
          _ => {
            error(ds, "E_TRACK_NUMBER", line_no, "track number must be 01..99")
            continue
          }
        }
        let t : Track = {
          number: n,
          mode: parts[2].to_upper(),
          line: line_no,
          metadata: Map([]),
          remarks: [],
          indexes: [],
        }
        f.tracks.push(t)
        track = Some(t)
      }
      "INDEX" => {
        let t = match track {
          Some(t) => t
          None => {
            error(ds, "E_SCOPE", line_no, "INDEX requires a TRACK")
            continue
          }
        }
        if t.metadata.contains("POSTGAP") {
          error(ds, "E_ORDER", line_no, "INDEX cannot follow POSTGAP")
        }
        let n = match decimal(parts[1], 99) {
          Some(n) => n
          None => {
            error(ds, "E_INDEX_NUMBER", line_no, "index number must be 00..99")
            continue
          }
        }
        let frames = match parse_time(parts[2]) {
          Ok(f) => f
          Err(m) => {
            error(ds, "E_TIME", line_no, m)
            continue
          }
        }
        t.indexes.push({ number: n, frames, line: line_no })
      }
      "TITLE" | "PERFORMER" | "SONGWRITER" => {
        let meta = match track {
          Some(t) => t.metadata
          None => {
            if file is Some(_) {
              error(
                ds,
                "E_SCOPE",
                line_no,
                command + " must precede FILE or belong to a TRACK",
              )
              continue
            }
            sheet.metadata
          }
        }
        put_metadata(meta, command, parts[1], line_no, ds)
      }
      "CATALOG" | "CDTEXTFILE" => {
        if file is Some(_) || !sheet.files.is_empty() {
          error(ds, "E_SCOPE", line_no, command + " must precede FILE")
          continue
        }
        if command == "CATALOG" &&
          (
            parts[1].length() != 13 ||
            !parts[1].all(fn(c) { c.is_ascii_digit() })
          ) {
          error(ds, "E_CATALOG", line_no, "CATALOG must contain 13 digits")
        }
        put_metadata(sheet.metadata, command, parts[1], line_no, ds)
      }
      _ => {
        let t = match track {
          Some(t) => t
          None => {
            error(ds, "E_SCOPE", line_no, command + " requires a TRACK")
            continue
          }
        }
        if command == "PREGAP" || command == "POSTGAP" {
          match parse_time(parts[1]) {
            Err(m) => error(ds, "E_TIME", line_no, m)
            Ok(_) => ()
          }
        }
        if command == "PREGAP" && !t.indexes.is_empty() {
          error(ds, "E_ORDER", line_no, "PREGAP must precede INDEX")
        }
        if command == "POSTGAP" && t.indexes.is_empty() {
          error(ds, "E_ORDER", line_no, "POSTGAP must follow INDEX")
        }
        if command == "FLAGS" {
          for flag in parts[1:] {
            if !["DCP", "4CH", "PRE", "SCMS"].contains(flag.to_upper()) {
              error(ds, "E_FLAGS", line_no, "unknown track flag: " + flag)
            }
          }
        }
        if command == "ISRC" {
          let v = parts[1]
          if v.length() != 12 ||
            !v[:2].all(fn(c) { c.is_ascii_alphabetic() }) ||
            !v[2:5].all(fn(c) { c.is_ascii_alphabetic() || c.is_ascii_digit() }) ||
            !v[5:].all(fn(c) { c.is_ascii_digit() }) {
            error(
              ds, "E_ISRC", line_no, "expected ISRC: two letters, three alphanumeric characters, seven digits",
            )
          }
        }
        let value = if command == "FLAGS" {
          parts[1:].join(" ").to_upper()
        } else {
          parts[1]
        }
        put_metadata(t.metadata, command, value, line_no, ds)
      }
    }
  }
  validate_sheet(sheet, ds)
  { sheet, diagnostics: ds }
}

///|
fn validate_sheet(sheet : Sheet, ds : Array[Diagnostic]) -> Unit {
  if sheet.files.is_empty() {
    error(ds, "E_EMPTY", 0, "no source files")
  }
  let mut previous_track = 0
  for f in sheet.files {
    if f.tracks.is_empty() {
      error(ds, "E_EMPTY_FILE", f.line, "FILE has no tracks")
    }
    let mut previous_time = -1
    for t in f.tracks {
      if t.mode != "AUDIO" {
        error(ds, "E_MODE", t.line, "this profile supports AUDIO tracks only")
      }
      if t.number <= previous_track {
        error(
          ds,
          "E_TRACK_ORDER",
          t.line,
          "track numbers must increase across the disc",
        )
      } else if previous_track > 0 && t.number != previous_track + 1 {
        warning(ds, "W_TRACK_GAP", t.line, "track numbering is not consecutive")
      }
      previous_track = t.number
      let mut previous_index = -1
      let mut seen_one = false
      for idx in t.indexes {
        if previous_index == -1 && idx.number > 1 {
          error(ds, "E_INDEX_ORDER", idx.line, "first index must be 00 or 01")
        }
        if previous_index >= 0 && idx.number != previous_index + 1 {
          error(
            ds,
            "E_INDEX_ORDER",
            idx.line,
            "indexes must increase consecutively",
          )
        }
        if idx.frames < previous_time {
          error(
            ds,
            "E_TIME_ORDER",
            idx.line,
            "indexes must not move backwards within a source file",
          )
        }
        if idx.number == 1 {
          seen_one = true
        }
        previous_index = idx.number
        previous_time = idx.frames
      }
      if !seen_one {
        error(ds, "E_MISSING_INDEX", t.line, "TRACK requires INDEX 01")
      }
      if t.metadata.contains("PREGAP") && t.indexes.any(fn(x) { x.number == 0 }) {
        warning(
          ds,
          "W_TWO_GAPS",
          t.line,
          "PREGAP is generated silence; INDEX 00 is separate source-file audio",
        )
      }
    }
  }
}
