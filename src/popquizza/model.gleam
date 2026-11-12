// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025 ⟁K <k@u27c.one>

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import tempo
import tempo/date
import tempo/month

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

pub type DayHistory {
  DayHistory(date: tempo.Date, score: Int, out_of: Int, results: List(Bool))
}

pub type QuizState {
  Loading
  LoadError
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
    history: List(DayHistory),
    show_history: Bool,
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

pub fn share_string(date: tempo.Date, results: List(Bool)) {
  let #(correct, incorrect) = share_symbols(date)
  list.map(results, fn(x) {
    case x {
      False -> incorrect
      True -> correct
    }
  })
  |> string.join("")
}

fn share_symbols(date: tempo.Date) -> #(String, String) {
  let year = date.get_year(date)
  let month = date.get_month(date) |> month.to_int
  let day = date.get_day(date)

  case month, day {
    1, 1 -> #("🎉", "🍾")
    2, 14 -> #("💘", "💔")
    3, 17 -> #("🍀", "🥔")
    10, 31 -> #("🎃", "👻")
    11, 5 -> #("🎆", "💥")
    12, 25 -> #("🎄", "🍊")
    12, 31 -> #("🥳", "⏳")
    _, _ ->
      case is_easter_sunday(year, month, day) {
        True -> #("🐣", "🥚")
        False -> #("✅", "❌")
      }
  }
}

fn is_easter_sunday(year: Int, month: Int, day: Int) -> Bool {
  let a = year % 19
  let b = year / 100
  let c = year % 100
  let d = b / 4
  let e = b % 4
  let f = { b + 8 } / 25
  let g = { b - f + 1 } / 3
  let h = { 19 * a + b - d - g + 15 } % 30
  let i = c / 4
  let k = c % 4
  let l = { 32 + 2 * e + 2 * i - h - k } % 7
  let m = { a + 11 * h + 22 * l } / 451
  let easter_month = { h + l - 7 * m + 114 } / 31
  let easter_day = { h + l - 7 * m + 114 } % 31 + 1
  month == easter_month && day == easter_day
}
