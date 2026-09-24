///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let example = "FILE album.wav WAVE\nTRACK 01 AUDIO\nINDEX 01 00:00:00\nTRACK 02 AUDIO\nINDEX 00 03:58:00\nINDEX 01 04:00:00"
  println(
    @cue.process_request("plan", example, "exclude", "{\"album.wav\":30000}"),
  )
}
