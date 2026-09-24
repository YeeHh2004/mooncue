///|
/// A player-ready entry. Start is file-local, in 1/75-second CD frames.
/// Empty performer/songwriter means unspecified. Track values override album values.
pub struct TrackEntry {
  number : Int
  file : String
  file_type : String
  title : String
  performer : String
  songwriter : String
  start_frame : Int
  line : Int
} derive(ToJson)

///|
/// Flatten a valid CUE into a playback catalog, applying CD-Text inheritance.
/// This does not inspect media files or implement audio playback.
pub fn catalog(text : String) -> Result[Array[TrackEntry], Array[Diagnostic]] {
  let report = parse(text)
  if !report.is_valid() {
    return Err(report.diagnostics)
  }
  let entries : Array[TrackEntry] = []
  for file in report.sheet.files {
    for track in file.tracks {
      entries.push({
        number: track.number,
        file: file.name,
        file_type: file.kind,
        title: track.metadata
        .get("TITLE")
        .unwrap_or("Track " + pad2(track.number)),
        performer: track.metadata
        .get("PERFORMER")
        .unwrap_or(report.sheet.metadata.get("PERFORMER").unwrap_or("")),
        songwriter: track.metadata
        .get("SONGWRITER")
        .unwrap_or(report.sheet.metadata.get("SONGWRITER").unwrap_or("")),
        start_frame: index_frame(track, 1).unwrap_or(0),
        line: track.line,
      })
    }
  }
  Ok(entries)
}
