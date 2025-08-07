// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025 ⟁K <k@u27c.one>

import lustre
import lustre/effect
import popquizza/model.{type Model, Model, Stats}
import popquizza/update.{type Msg}
import popquizza/view
import rsvp
import tempo/date

pub fn main() {
  let app = lustre.application(init, update.update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  let model =
    Model(
      title: "Loading",
      url: "popquizza.com",
      questions: [],
      date: date.current_local(),
      launch_date: date.literal(model.launch_date),
      stats: Stats(streak: 0, count: 0, total: 0),
      state: model.Loading,
    )

  #(
    model,
    rsvp.get(
      "/priv/static/questions/" <> model.date_format(model.date) <> ".txt",
      rsvp.expect_text(update.AppReadQuestions),
    ),
  )
}