///|
test "file comments stay with their own file across normalization" {
  let input = "REM album note\nFILE a.wav WAVE\nREM source A\nTRACK 01 AUDIO\nREM track one\nINDEX 01 00:00:00\nFILE b.wav WAVE\nREM source B\nTRACK 02 AUDIO\nINDEX 01 00:00:00"
  let a = @mooncue.parse(input)
  assert_true(a.is_valid())
  assert_eq(a.sheet.remarks, ["album note"])
  assert_eq(a.sheet.files[0].remarks, ["source A"])
  assert_eq(a.sheet.files[1].remarks, ["source B"])
  assert_eq(a.sheet.files[0].tracks[0].remarks, ["track one"])
  match @mooncue.normalize(input) {
    Ok(text) => {
      let b = @mooncue.parse(text)
      assert_true(b.is_valid())
      assert_eq(b.sheet.remarks, a.sheet.remarks)
      assert_eq(b.sheet.files[0].remarks, a.sheet.files[0].remarks)
      assert_eq(b.sheet.files[1].remarks, a.sheet.files[1].remarks)
      assert_eq(b.sheet.files[0].tracks[0].remarks, ["track one"])
      assert_eq(@mooncue.normalize(text), Ok(text))
    }
    Err(_) => fail("valid input rejected")
  }
}
