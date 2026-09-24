///|
fn quoted(value : String) -> String {
  "\"" + value + "\""
}

///|
fn emit_metadata(
  lines : Array[String],
  meta : Map[String, String],
  keys : Array[String],
  indent : String,
) -> Unit {
  for key in keys {
    if meta.get(key) is Some(v) {
      let value = if ["TITLE", "PERFORMER", "SONGWRITER", "CDTEXTFILE"].contains(
          key,
        ) {
        quoted(v)
      } else {
        v
      }
      lines.push(indent + key + " " + value)
    }
  }
}

///|
/// Normalize valid CUE text without silently dropping unsupported commands.
pub fn normalize(text : String) -> Result[String, Array[Diagnostic]] {
  let report = parse(text)
  if !report.is_valid() {
    return Err(report.diagnostics)
  }
  let sheet = report.sheet
  let lines : Array[String] = []
  emit_metadata(
    lines,
    sheet.metadata,
    ["CATALOG", "CDTEXTFILE", "TITLE", "PERFORMER", "SONGWRITER"],
    "",
  )
  for rem in sheet.remarks {
    lines.push("REM " + rem)
  }
  for file in sheet.files {
    lines.push("FILE " + quoted(file.name) + " " + file.kind)
    for rem in file.remarks {
      lines.push("  REM " + rem)
    }
    for track in file.tracks {
      lines.push("  TRACK " + pad2(track.number) + " " + track.mode)
      emit_metadata(
        lines,
        track.metadata,
        ["TITLE", "PERFORMER", "SONGWRITER", "ISRC", "FLAGS", "PREGAP"],
        "    ",
      )
      for rem in track.remarks {
        lines.push("    REM " + rem)
      }
      for index in track.indexes {
        match format_time(index.frames) {
          Ok(time) => lines.push("    INDEX " + pad2(index.number) + " " + time)
          Err(_) => () // All values are validated by parse.
        }
      }
      emit_metadata(lines, track.metadata, ["POSTGAP"], "    ")
    }
  }
  Ok(lines.join("\n") + "\n")
}

///|
fn index_frame(t : Track, n : Int) -> Int? {
  for idx in t.indexes {
    if idx.number == n {
      return Some(idx.frames)
    }
  }
  None
}

///|
fn gap_frames(t : Track, name : String) -> Int {
  match t.metadata.get(name) {
    Some(s) =>
      match parse_time(s) {
        Ok(n) => n
        Err(_) => 0
      }
    None => 0
  }
}

///|
/// Plan source-file slices only. PREGAP/POSTGAP are separate silence instructions.
/// `durations` maps exact FILE names to decoded audio lengths in CD frames.
/// Missing lengths leave the final segment end unknown; never infer media length.
pub fn plan(
  text : String,
  policy : GapPolicy,
  durations : Map[String, Int],
) -> Result[Array[Segment], Array[Diagnostic]] {
  let report = parse(text)
  if !report.is_valid() {
    return Err(report.diagnostics)
  }
  let issues : Array[Diagnostic] = []
  let segments : Array[Segment] = []
  for name, length in durations {
    if length <= 0 {
      error(
        issues,
        "E_DURATION",
        0,
        "source duration must be positive: " + name,
      )
    }
    if !report.sheet.files.any(fn(f) { f.name == name }) {
      error(
        issues,
        "E_DURATION_FILE",
        0,
        "duration refers to unknown FILE: " + name,
      )
    }
  }
  for file in report.sheet.files {
    if file.kind == "BINARY" || file.kind == "MOTOROLA" {
      error(
        issues,
        "E_PLAN_FORMAT",
        file.line,
        "split planning requires decoded audio (WAVE, AIFF or MP3), not raw disc images",
      )
      continue
    }
    let length = durations.get(file.name)
    for i, track in file.tracks {
      let start_one = index_frame(track, 1).unwrap_or(0)
      let start = match policy {
        PrependNext => index_frame(track, 0).unwrap_or(start_one)
        _ => start_one
      }
      let end = if i + 1 < file.tracks.length() {
        let next = file.tracks[i + 1]
        let next_one = index_frame(next, 1).unwrap_or(0)
        Some(
          match policy {
            AppendPrevious => next_one
            _ => index_frame(next, 0).unwrap_or(next_one)
          },
        )
      } else {
        length
      }
      if end is Some(e) && e <= start {
        error(
          issues,
          "E_EMPTY_SEGMENT",
          track.line,
          "planned audio range is empty or reversed",
        )
      }
      if length is Some(n) {
        for idx in track.indexes {
          if idx.frames >= n {
            error(
              issues,
              "E_BEYOND_EOF",
              idx.line,
              "index lies at or beyond supplied source length",
            )
          }
        }
      }
      segments.push({
        file: file.name,
        track: track.number,
        title: track.metadata
        .get("TITLE")
        .unwrap_or("Track " + pad2(track.number)),
        start_frame: start,
        end_frame: end,
        generated_pregap_frames: gap_frames(track, "PREGAP"),
        generated_postgap_frames: gap_frames(track, "POSTGAP"),
      })
    }
  }
  if issues.is_empty() {
    Ok(segments)
  } else {
    Err(issues)
  }
}

///|
/// Stable JSON response envelope shared by the CLI and other JS consumers.
/// Commands: check, normalize, plan. Invalid input never returns a partial plan.
pub fn process_request(
  command : String,
  text : String,
  policy_name : String,
  durations_json : String,
) -> String {
  let report = parse(text)
  if command == "check" {
    let response : Json = {
      "ok": report.is_valid().to_json(),
      "output": report.sheet.to_json(),
      "diagnostics": report.diagnostics.to_json(),
    }
    return response.stringify(indent=2)
  }
  if command == "normalize" {
    return match normalize(text) {
      Ok(s) =>
        (
          {
            "ok": true,
            "output": s.to_json(),
            "diagnostics": report.diagnostics.to_json(),
          } : Json).stringify(indent=2)
      Err(ds) =>
        ({ "ok": false, "diagnostics": ds.to_json() } : Json).stringify(
          indent=2,
        )
    }
  }
  if command == "plan" {
    let policy = match policy_name {
      "exclude" => Exclude
      "append" => AppendPrevious
      "prepend" => PrependNext
      _ =>
        return (
          {
            "ok": false,
            "error": "gap policy must be exclude, append or prepend",
          } : Json).stringify()
    }
    let durations : Map[String, Int] = @json.from_json(
      @json.parse(durations_json),
    ) catch {
      _ =>
        return (
          {
            "ok": false,
            "error": "durations must be a JSON object mapping filenames to integer CD-frame lengths",
          } : Json).stringify()
    }
    return match plan(text, policy, durations) {
      Ok(segments) =>
        (
          {
            "ok": true,
            "timebase": "1/75",
            "gap_policy": policy_name.to_json(),
            "output": segments.to_json(),
            "diagnostics": report.diagnostics.to_json(),
          } : Json).stringify(indent=2)
      Err(ds) =>
        ({ "ok": false, "diagnostics": ds.to_json() } : Json).stringify(
          indent=2,
        )
    }
  }
  ({ "ok": false, "error": "unknown command" } : Json).stringify()
}
