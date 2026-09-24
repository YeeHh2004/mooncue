///|
/// A diagnostic points to a one-based source line (0 means whole document).
pub struct Diagnostic {
  severity : String
  code : String
  line : Int
  message : String
} derive(Eq, ToJson, @debug.Debug)

///|
/// An index uses integer CD frames: exactly 75 frames per second.
pub struct CueIndex {
  number : Int
  frames : Int
  line : Int
} derive(Eq, ToJson)

///|
/// Track metadata stores TITLE, PERFORMER, SONGWRITER, ISRC, FLAGS and gaps.
pub struct Track {
  number : Int
  mode : String
  line : Int
  metadata : Map[String, String]
  remarks : Array[String]
  indexes : Array[CueIndex]
} derive(ToJson)

///|
pub struct CueFile {
  name : String
  kind : String
  line : Int
  tracks : Array[Track]
  remarks : Array[String]
} derive(ToJson)

///|
pub struct Sheet {
  metadata : Map[String, String]
  remarks : Array[String]
  files : Array[CueFile]
} derive(ToJson)

///|
/// Parsing recovers at line boundaries so one run can report multiple errors.
pub struct Report {
  sheet : Sheet
  diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
pub fn Report::is_valid(self : Report) -> Bool {
  !self.diagnostics.any(fn(d) { d.severity == "error" })
}

///|
/// Integer, half-open source range. None is an unknown source-file end.
pub struct Segment {
  file : String
  track : Int
  title : String
  start_frame : Int
  end_frame : Int?
  generated_pregap_frames : Int
  generated_postgap_frames : Int
} derive(Eq)

///|
/// Preserve unknown end_frame as an explicit JSON null (not an absent field).
pub impl ToJson for Segment with fn to_json(self) {
  {
    "file": self.file.to_json(),
    "track": self.track.to_json(),
    "title": self.title.to_json(),
    "start_frame": self.start_frame.to_json(),
    "end_frame": match self.end_frame {
      Some(n) => n.to_json()
      None => Json::null()
    },
    "generated_pregap_frames": self.generated_pregap_frames.to_json(),
    "generated_postgap_frames": self.generated_postgap_frames.to_json(),
  }
}

///|
/// INDEX 00 data is omitted, attached to previous, or attached to next track.
pub(all) enum GapPolicy {
  Exclude
  AppendPrevious
  PrependNext
} derive(Eq)

///|
fn error(
  ds : Array[Diagnostic],
  code : String,
  line : Int,
  message : String,
) -> Unit {
  ds.push({ severity: "error", code, line, message })
}

///|
fn warning(
  ds : Array[Diagnostic],
  code : String,
  line : Int,
  message : String,
) -> Unit {
  ds.push({ severity: "warning", code, line, message })
}

///|
/// Bounded decimal parsing rejects signs, whitespace, and overflow.
fn decimal(text : String, maximum : Int) -> Int? {
  if text.is_empty() {
    return None
  }
  let mut value = 0
  for c in text.iter() {
    if !c.is_ascii_digit() {
      return None
    }
    let digit = c.to_int() - 48
    if value > (maximum - digit) / 10 || digit > maximum {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
/// Supported CUE timestamps use two-digit mm:ss:ff, seconds <60, frames <75.
pub fn parse_time(text : String) -> Result[Int, String] {
  let fields = text.split(":").map(fn(s) { s.to_owned() }).collect()
  if fields.length() != 3 || fields.any(fn(s) { s.length() != 2 }) {
    return Err("expected mm:ss:ff (two digits each)")
  }
  match
    (decimal(fields[0], 99), decimal(fields[1], 59), decimal(fields[2], 74)) {
    (Some(m), Some(s), Some(f)) => Ok((m * 60 + s) * 75 + f)
    _ =>
      Err("timestamp out of range: minutes 00-99, seconds 00-59, frames 00-74")
  }
}

///|
fn pad2(n : Int) -> String {
  n.to_string().pad_start(2, '0')
}

///|
pub fn format_time(frames : Int) -> Result[String, String] {
  if frames < 0 || frames >= 100 * 60 * 75 {
    return Err("CUE time outside 00:00:00..99:59:74")
  }
  Ok(
    pad2(frames / 4500) + ":" + pad2(frames / 75 % 60) + ":" + pad2(frames % 75),
  )
}
