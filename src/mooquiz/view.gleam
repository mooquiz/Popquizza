// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025 ⟁K <k@u27c.one>

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{Some}
import lustre/attribute
import lustre/element/html
import lustre/event
import mooquiz/model.{type Model}
import mooquiz/update
import number_to_words
import tempo
import tempo/date

pub fn view(model: Model) {
  html.div([attribute.class("py-8")], [
    html.header([], [
      html.h1(
        [
          attribute.class(
            "font-logo font-[800] text-shadow-lg shadow-zinc-200 text-5xl text-head dark:d-head",
          ),
        ],
        [html.text("POPQUIZZA")],
      ),
    ]),
    html.main([], [
      html.h2(
        [attribute.class("text-xl font-bold text-subhead dark:text-d-subhead")],
        [html.text(model.title)],
      ),
      html.h2(
        [
          attribute.class(
            "text-xl font-bold mb-8 text-subhead dark:text-d-subhead",
          ),
        ],
        [
          html.text(
            "Day "
            <> model.launch_date
            |> date.difference(model.date)
            |> int.add(1)
            |> number_to_words.number_to_words()
            <> ": "
            <> date.format(model.date, tempo.CustomDate("DD-MM-YY")),
          ),
        ],
      ),
      case date.is_earlier(model.date, model.launch_date) {
        True -> {
          html.div(
            [
              attribute.class(
                "dark:bg-gray-700 text-gray-300 border rounded border-gray-300 dark:border-gray-700 bg-white dark:bg-d-b p-4 font-semibold my-4",
              ),
            ],
            [
              html.text(
                "Official launch on Wednesday 23 April 2025! Pop back then for real questions! ",
              ),
            ],
          )
        }
        False -> html.span([], [])
      },
      html.div(
        [attribute.class("flex flex-col gap-6 mb-4")],
        list.map(model.questions, fn(q) {
          html.div([], [
            html.h3([attribute.class("text-lg font-semibold text-head")], [
              html.text(q.text),
            ]),
            html.div(
              [attribute.class("flex flex-col gap-2")],
              list.map(q.answers, fn(answer) {
                answer_div(answer, q, model.state)
              }),
            ),
          ])
        }),
      ),
      case model.state {
        model.Submitted -> result_panel(model)
        model.ShowAnswers -> {
          html.button(
            [
              event.on_click(update.UserClickedShowResults),
              attribute.class(button_css(model.unanswered_questions(model))),
            ],
            [html.text("Show Results")],
          )
        }
        _ -> {
          html.button(
            [
              event.on_click(update.UserSubmittedAnswers),
              attribute.class(button_css(model.unanswered_questions(model))),
            ],
            [html.text("Submit")],
          )
        }
      },
    ]),
  ])
}

fn button_css(active: Bool) {
  "px-4 py-2 rounded-lg font-semibold transition "
  <> case active {
    True ->
      "bg-gray-300 text-gray-500 cursor-not-allowed opacity-60 dark:bg-slate-700 dark:text-slate-400"
    False ->
      "bg-head text-white hover:bg-purple-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-head dark:hover:bg-purple-500"
  }
}

fn results_title(score: Int) {
  case score {
    0 -> "Bottom of the pops!"
    1 -> "Tomorrow's another day!"
    2 -> "Must Try Harder!"
    3 -> "Keep on keeping on!"
    4 -> "Bubbling under!"
    5 -> "Highest new entry!"
    6 -> "Rising star!"
    7 -> "Climbing the chart!"
    8 -> "Flying high!"
    9 -> "Almost there!"
    10 -> "No 1 Smash Hit!"
    _ -> "Well done!"
  }
}

fn score_div(title: String, number: Int) {
  score_div_float(title, int.to_float(number), 0)
}

fn score_div_float(title: String, number: Float, precision: Int) {
  html.div([attribute.class("grow")], [
    html.div([attribute.class("text-3xl text-center")], [
      html.text(case precision {
        0 -> number |> float.truncate |> int.to_string
        _ -> number |> float.to_precision(precision) |> float.to_string
      }),
    ]),
    html.div([attribute.class("text-center")], [html.text(title)]),
  ])
}

fn result_panel(model: Model) {
  case model.state {
    model.Loaded -> {
      html.button(
        [
          event.on_click(update.UserToggledResultPanel),
          attribute.class(button_css(False)),
        ],
        [html.text("Show Results")],
      )
    }
    _ -> {
      let result = model.calculate_results(model.questions)
      html.div(
        [
          attribute.class(
            "fixed inset-0 bg-black/30 backdrop-blur-sm flex items-center justify-center z-50 text-zinc-800",
          ),
        ],
        [
          html.div(
            [
              attribute.class(
                "border-2 border-zinc-600 rounded-lg p-4 absolute bg-white",
              ),
            ],
            [
              html.header([attribute.class("flex gap-4")], [
                html.h1(
                  [
                    attribute.class(
                      "text-xl font-logo text-head font-extrabold mb-6 grow",
                    ),
                  ],
                  [html.text(results_title(result.score))],
                ),
                html.a(
                  [
                    event.on_click(update.UserToggledResultPanel),
                    attribute.class(
                      "duration-200 active:translate-y-0.5 active:scale-95 text-lg font-bold cursor-pointer",
                    ),
                  ],
                  [html.text("✕")],
                ),
              ]),
              html.p([], [
                html.text(
                  "You scored "
                  <> int.to_string(result.score)
                  <> " out of "
                  <> int.to_string(result.out_of),
                ),
              ]),
              html.p([attribute.class("mb-6")], [
                html.text(model.share_string(result.results)),
              ]),
              html.div(
                [attribute.class("flex flex-row border-t border-b my-6 py-2")],
                [
                  score_div("Count", model.stats.count),
                  score_div("Streak", model.stats.streak),
                  score_div_float(
                    "Average",
                    int.to_float(model.stats.total)
                      /. int.to_float(model.stats.count),
                    2,
                  ),
                  score_div("Total", model.stats.total),
                ],
              ),
              html.p([attribute.class("mb-6")], [
                html.text("A new set of questions will appear at midnight"),
              ]),
              html.p([attribute.class("mb-6")], [
                html.a(
                  [
                    attribute.class(
                      "hover:underline hover:text-blue-700 text-blue-500",
                    ),
                    attribute.href(
                      "https://www.facebook.com/profile.php?id=61575507458149",
                    ),
                  ],
                  [html.text("Join us on our Facebook page!")],
                ),
              ]),
              html.div([attribute.class("flex gap-4")], [
                html.button(
                  [
                    event.on_click(update.UserClickedShareResults),
                    attribute.class(button_css(False)),
                  ],
                  [html.text("Share Results")],
                ),
                html.button(
                  [
                    event.on_click(update.UserToggledResultPanel),
                    attribute.class(
                      "px-4 py-2 rounded-lg font-semibold transition bg-subhead text-white hover:bg-cyan-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-head dark:hover:bg-cyan-600",
                    ),
                  ],
                  [html.text("See Answers")],
                ),
              ]),
            ],
          ),
        ],
      )
    }
  }
}

fn answer_radio(question: model.Question, answer: model.Answer, state: model.QuizState) {
  case
    state,
    question.selected == Some(answer.pos),
    question.correct == answer.pos
  {
    model.Loaded, _, _ -> {
      html.input([
        attribute.type_("radio"),
        attribute.name("question-" <> int.to_string(question.id)),
        attribute.value(
          int.to_string(question.id) <> "-" <> int.to_string(answer.pos),
        ),
        event.on_input(update.UserSelectedAnswer),
      ])
    }
    _, _, True -> html.text("✔️")
    _, True, False -> html.text("❌")
    _, _, _ -> html.text("")
  }
}

fn answer_div(answer: model.Answer, question: model.Question, state: model.QuizState) {
  let bg = case
    state,
    question.selected == Some(answer.pos),
    question.correct == answer.pos
  {
    model.Loaded, True, _ -> "bg-selected dark:bg-d-selected"
    _, True, True -> "bg-correct dark:bg-d-correct font-bold"
    _, True, False -> "bg-incorrect dark:bg-d-incorrect font-bold"
    model.Loaded, _, _ ->
      "bg-question dark:bg-d-question hover:bg-question-hover dark:hover:bg-d-question-hover cursor-pointer"
    _, _, _ -> "bg-question dark:bg-d-question"
  }

  html.label([attribute.class("block w-full flex duration-200 p-2 " <> bg)], [
    html.span([attribute.class("grow")], [html.text(answer.text)]),
    answer_radio(question, answer, state),
  ])
}