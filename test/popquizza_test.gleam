import gleeunit
import gleeunit/should
import popquizza/model
import tempo/date

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  1
  |> should.equal(1)
}

pub fn special_day_share_emojis_test() {
  model.share_string(date.literal("2026-11-05"), [True, False])
  |> should.equal("🎆💥")
  model.share_string(date.literal("2026-12-25"), [True, False])
  |> should.equal("🎄🍊")
  model.share_string(date.literal("2026-04-05"), [True, False])
  |> should.equal("🐣🥚")
  model.share_string(date.literal("2026-06-01"), [True, False])
  |> should.equal("✅❌")
}
