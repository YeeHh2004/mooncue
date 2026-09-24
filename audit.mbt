///|
/// Audio deliberately left out of a split plan, with file-local boundaries.
pub struct OmittedRange {
  start_frame : Int
  end_frame : Int
} derive(Eq, ToJson)

///|
/// Coverage for one FILE declaration. Unknown source length stays unknown.
pub struct SourceCoverage {
  file : String
  source_number : Int
  total_frames : Int?
  selected_frames : Int?
  known_omitted_frames : Int
  omitted : Array[OmittedRange]
}

///|
pub impl ToJson for SourceCoverage with fn to_json(self) {
  {
    "file": self.file.to_json(),
    "source_number": self.source_number.to_json(),
    "total_frames": match self.total_frames {
      Some(n) => n.to_json()
      None => Json::null()
    },
    "selected_frames": match self.selected_frames {
      Some(n) => n.to_json()
      None => Json::null()
    },
    "known_omitted_frames": self.known_omitted_frames.to_json(),
    "omitted": self.omitted.to_json(),
  }
}

///|
pub struct PlanAudit {
  complete : Bool
  segments : Array[Segment]
  sources : Array[SourceCoverage]
} derive(ToJson)

///|
/// Explain source audio excluded by each gap policy, including hidden lead-in.
/// selected_frames excludes synthetic PREGAP/POSTGAP silence. Completeness means
/// supplied lengths close every source range, not that media was inspected.
pub fn audit_plan(
  text : String,
  policy : GapPolicy,
  durations : Map[String, Int],
) -> Result[PlanAudit, Array[Diagnostic]] {
  let segments = match plan(text, policy, durations) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let sheet = parse(text).sheet
  let sources : Array[SourceCoverage] = []
  let mut segment_index = 0
  let mut complete = true
  for i, file in sheet.files {
    let omitted : Array[OmittedRange] = []
    let mut cursor = 0
    let mut selected = 0
    let mut omitted_count = 0
    let mut known = true
    for _ in file.tracks {
      let segment = segments[segment_index]
      segment_index += 1
      if segment.start_frame > cursor {
        omitted.push({ start_frame: cursor, end_frame: segment.start_frame, })
        omitted_count += segment.start_frame - cursor
      }
      match segment.end_frame {
        Some(end) => {
          selected += end - segment.start_frame
          cursor = end
        }
        None => {
          known = false
          complete = false
        }
      }
    }
    sources.push({
      file: file.name,
      source_number: i + 1,
      total_frames: durations.get(file.name),
      selected_frames: if known {
        Some(selected)
      } else {
        None
      },
      known_omitted_frames: omitted_count,
      omitted,
    })
  }
  Ok({ complete, segments, sources, })
}
