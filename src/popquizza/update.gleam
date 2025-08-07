// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025 ⟁K <k@u27c.one>

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/effect
import popquizza/model.{type Model, type Stats, Model, Stats}
import rsvp
import tempo
import tempo/date

pub type Msg {
  AppCalculatedStats(Stats)
  UserClickedShareResults
  AppReadAnswers(String)
  UserSubmittedAnswers
  UserToggledResultPanel
  UserSelectedAnswer(String)
  AppReadQuestions(Result(String, rsvp.Error))
  UserClickedShowResults
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    AppCalculatedStats(stats) -> app_calculated_stats(model, stats)
    UserClickedShareResults -> user_clicked_share_results(model)
    UserToggledResultPanel -> user_toggled_result_panel(model)
    AppReadAnswers(answers) -> app_read_answers(model, answers)
    AppReadQuestions(Ok(file)) -> app_read_questions(model, file)
    AppReadQuestions(Error(_)) -> #(model, effect.none())
    UserSubmittedAnswers -> user_submitted_answers(model)
    UserSelectedAnswer(value) -> user_selected_answer(model, value)
    UserClickedShowResults -> user_clicked_show_results(model)
  }
}

fn user_clicked_show_results(model: Model) {
  #(Model(..model, state: model.Submitted), effect.none())
}

fn app_calculated_stats(model: Model, stats: Stats) {
  #(Model(..model, stats: stats), effect.none())
}

fn user_clicked_share_results(model: Model) {
  #(
    model,
    share_results(model.title, model.url, model.calculate_results(model.questions)),
  )
}

fn user_toggled_result_panel(model: Model) {
  #(
    Model(..model, state: case model.state {
      model.ShowAnswers -> model.Submitted
      model.Submitted -> model.ShowAnswers
      x -> x
    }),
    effect.none(),
  )
}

fn result_decoder() {
  use answers <- decode.field("answers", decode.list(decode.int))
  use results <- decode.field("results", decode.list(decode.bool))
  use score <- decode.field("score", decode.int)
  use out_of <- decode.field("outOf", decode.int)
  decode.success(model.QuizResult(results:, answers:, score:, out_of:))
}

fn app_read_answers(model: Model, answers: String) {
  case json.parse(answers, result_decoder()) {
    Error(_) -> #(model, effect.none())
    Ok(attempt) -> {
      let questions =
        attempt.answers
        |> list.zip(model.questions)
        |> list.map(fn(x) { model.Question(..x.1, selected: Some(x.0)) })

      case attempt.out_of {
        0 -> #(model, effect.none())
        _ -> {
          #(
            Model(..model, questions: questions, state: model.Submitted),
            effect.from(fn(dispatch) { calculate_stats(model, dispatch) }),
          )
        }
      }
    }
  }
}

fn app_read_questions(model, file) {
  let assert [title, ..questions] = file |> string.trim |> string.split("\n\n")
  let questions =
    list.map(questions, fn(q) {
      let assert [question_text, correct, ..answers] =
        q
        |> string.split("\n")
        |> list.map(fn(x) { string.trim(x) })

      let answers =
        answers
        |> list.length
        |> list.range(1)
        |> list.reverse
        |> list.zip(answers)
        |> list.map(fn(a) {
          let #(id, text) = a
          model.Answer(id, text)
        })

      #(question_text, correct, answers)
    })

  let questions =
    questions
    |> list.length
    |> list.range(1)
    |> list.reverse
    |> list.zip(questions)
    |> list.map(fn(q) {
      let #(id, #(question_text, correct, answers)) = q
      model.Question(
        id,
        question_text,
        answers,
        case int.parse(correct) {
          Ok(correct) -> correct
          Error(Nil) -> 0
        },
        None,
      )
    })

  #(
    Model(..model, title: title, questions: questions, state: model.Loaded),
    get_today(model),
  )
}

fn user_submitted_answers(model: Model) {
  case model.unanswered_questions(model) {
    True -> #(model, effect.none())
    False -> #(Model(..model, state: model.Submitted), save_results(model))
  }
}

fn user_selected_answer(model: Model, value) {
  case string.split(value, "-") {
    [question_id, answer] -> {
      case int.parse(question_id) {
        Ok(qpos) -> {
          let questions =
            list.map(model.questions, fn(question) {
              case qpos == question.id {
                False -> question
                True ->
                  case int.parse(answer) {
                    Ok(apos) -> model.Question(..question, selected: Some(apos))
                    Error(Nil) -> question
                  }
              }
            })
          #(Model(..model, questions: questions), effect.none())
        }
        Error(Nil) -> #(model, effect.none())
      }
    }
    _ -> #(model, effect.none())
  }
}

fn calculate_stats(model: Model, dispatch: fn(Msg) -> Nil) {
  dispatch(
    AppCalculatedStats(Stats(
      streak: calc_streak(model.date, date.subtract(model.launch_date, 1)),
      count: calc_count(model.date, date.subtract(model.launch_date, 1)),
      total: calc_total(model.date, date.subtract(model.launch_date, 1)),
    )),
  )
}

fn save_results(model: Model) {
  effect.from(fn(dispatch) {
    set_localstorage(
      model.date_format(model.date),
      model.questions
        |> model.calculate_results()
        |> encode_result()
        |> json.to_string,
    )
    calculate_stats(model, dispatch)
  })
}

fn share_results(title: String, url: String, result: model.QuizResult) {
  let share_data =
    json.object([
      #(
        "text",
        json.string(
          "I scored "
          <> int.to_string(result.score)
          <> "/"
          <> int.to_string(result.out_of)
          <> " on "
          <> title
          <> "\n"
          <> model.share_string(result.results)
          <> "\n"
          <> url
          <> " #popquizza",
        ),
      ),
    ])
  effect.from(fn(_dispatch) { share_results_js(share_data) })
}

fn get_today(model: Model) {
  effect.from(fn(dispatch) {
    case get_localstorage(model.date_format(model.date)) {
      Ok(result) -> {
        dispatch(AppReadAnswers(result))
        Nil
      }
      Error(_) -> Nil
    }
  })
}

fn calc_total(date: tempo.Date, stop_at: tempo.Date) {
  case date {
    date if date == stop_at -> 0
    date -> {
      case get_localstorage(model.date_format(date)) {
        Ok(result) ->
          case json.parse(result, result_decoder()) {
            Error(_) -> 0
            Ok(attempt) ->
              attempt.score + calc_total(date.subtract(date, 1), stop_at)
          }
        Error(_) -> calc_total(date.subtract(date, 1), stop_at)
      }
    }
  }
}

fn calc_count(date: tempo.Date, stop_at: tempo.Date) {
  case date {
    date if date == stop_at -> 0
    date ->
      case get_localstorage(model.date_format(date)) {
        Error(_) -> 0
        Ok(_) -> 1
      }
      + calc_count(date.subtract(date, 1), stop_at)
  }
}

fn calc_streak(date: tempo.Date, stop_at: tempo.Date) {
  case date {
    date if date == stop_at -> 0
    date ->
      case get_localstorage(model.date_format(date)) {
        Error(_) -> 0
        Ok(_) -> {
          1 + calc_streak(date.subtract(date, 1), stop_at)
        }
      }
  }
}

fn encode_result(result: model.QuizResult) -> json.Json {
  json.object([
    #("results", json.array(result.results, of: json.bool)),
    #("answers", json.array(result.answers, of: json.int)),
    #("score", json.int(result.score)),
    #("outOf", json.int(result.out_of)),
  ])
}

@external(javascript, "../app.ffi.mjs", "share_results")
fn share_results_js(_share_data: json.Json) -> Nil {
  Nil
}

@external(javascript, "../app.ffi.mjs", "set_localstorage")
fn set_localstorage(_key: String, _value: String) -> Nil {
  Nil
}

@external(javascript, "../app.ffi.mjs", "get_localstorage")
fn get_localstorage(_key: String) -> Result(String, Nil) {
  Error(Nil)
}

