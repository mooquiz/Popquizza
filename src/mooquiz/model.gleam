// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025 ⟁K <k@u27c.one>

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import tempo
import tempo/date

pub type Answer {
  Answer(pos: Int, text: String)
}

pub type Question {
  Question(
    id: Int,
    text: String,
    answers: List(Answer),
    correct: Int,
    selected: Option(Int),
  )
}

pub type QuizResult {
  QuizResult(results: List(Bool), answers: List(Int), score: Int, out_of: Int)
}

pub type Stats {
  Stats(streak: Int, count: Int, total: Int)
}

pub type QuizState {
  Loading
  Loaded
  Submitted
  ShowAnswers
}

pub type Model {
  Model(
    title: String,
    url: String,
    questions: List(Question),
    date: tempo.Date,
    launch_date: tempo.Date,
    stats: Stats,
    state: QuizState,
  )
}

pub const launch_date = "2025-04-23"

// Pure utility functions that operate on the data types

pub fn date_format(date: tempo.Date) {
  date |> date.to_string |> string.replace("-", "")
}

pub fn unanswered_questions(model: Model) {
  list.any(model.questions, fn(q) { q.selected == None })
}

pub fn calculate_results(questions: List(Question)) {
  let out_of = list.length(questions)
  let answers =
    list.map(questions, fn(q) {
      case q.selected {
        Some(answer) -> answer
        None -> panic as "Unfilled scored should never have been saved"
      }
    })
  let results = list.map(questions, fn(q) { q.selected == Some(q.correct) })
  let score = list.count(questions, fn(q) { q.selected == Some(q.correct) })
  QuizResult(results: results, answers: answers, score: score, out_of: out_of)
}

pub fn share_string(results: List(Bool)) {
  list.map(results, fn(x) {
    case x {
      False -> "❌"
      True -> "✅"
    }
  })
  |> string.join("")
}