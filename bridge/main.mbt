///|
pub fn process_request(
  command : String,
  text : String,
  policy : String,
  durations : String,
) -> String {
  @cue.process_request(command, text, policy, durations)
}

///|
fn main {
  ()
}
