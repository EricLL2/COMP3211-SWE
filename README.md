# COMP3211 PIM

Command-line Personal Information Management system for PolyU COMP3211 Software Engineering (Fall 2026).

The assignment brief is [`Project Description.pdf`](<Project Description.pdf>). Requirements are specified in the SRS and the design, with its decisions, in the design document. Implementation must follow those files, not reopen them.

## Documents

Every document source lives under `docs/`. The root holds the brief, the submitted PDFs, this README, and `CLAUDE.md`. Each graded document is written in Markdown in `docs/deliverables/` and typeset into a PDF at the root (`sh docs/build.sh`). The brief requires the requirements coverage report and the line-coverage report in the root folder of the source code: those are `REQUIREMENTS.pdf` and `COVERAGE_REPORT.pdf`. Folders in `docs/` whose names start with `_` hold supporting material: diagram sources (`_diagrams`), the page design (`_typeset`), the system-video script (`_video`), and the deck's clips and images (`_media`).

| Source | PDF | What it is |
|---|---|---|
| [`docs/deliverables/SRS.md`](docs/deliverables/SRS.md) | [`SRS.pdf`](SRS.pdf) | Software requirements specification (deliverable 1): scope, glossary, every functional and non-functional requirement |
| [`docs/deliverables/DESIGN.md`](docs/deliverables/DESIGN.md) | [`DESIGN_REPORT.pdf`](DESIGN_REPORT.pdf) | Design document (deliverable 2): MVC architecture, classes, PIM File format, search-then-update sequence; §5 records the design decisions |
| [`docs/deliverables/USER.md`](docs/deliverables/USER.md) | [`USER_MANUAL.pdf`](USER_MANUAL.pdf) | User manual |
| [`docs/deliverables/DEVELOPER.md`](docs/deliverables/DEVELOPER.md) | [`DEVELOPER_MANUAL.pdf`](DEVELOPER_MANUAL.pdf) | Developer manual |
| [`docs/deliverables/REQUIREMENTS.md`](docs/deliverables/REQUIREMENTS.md) | [`REQUIREMENTS.pdf`](REQUIREMENTS.pdf) | Requirements coverage report (PDF at the source root, as the brief requires) |
| [`docs/deliverables/coverage.txt`](docs/deliverables/coverage.txt) | [`COVERAGE_REPORT.pdf`](COVERAGE_REPORT.pdf) | `model/` line coverage, written by `tests/coverage_report.py` (PDF at the source root, as the brief requires) |
| [`docs/presentation/`](docs/presentation/) | [`Presentation Slides.pdf`](<Presentation Slides.pdf>) | Presentation deck (`PIM-presentation.pptx`) with speaker notes (deliverable 5) |
| [`CLAUDE.md`](CLAUDE.md) | — | Rules for AI agents: precedence, scope, architecture, gates |

Use the SRS glossary (§3) terms as written. Do not treat **Name** as a title, **Label** as identity, or **Note** as a field name.

## Product in one paragraph

A single-user terminal PIM. The user manages Notes, Tasks, Events, and Contacts in a Working Collection, searches with contains / time comparison / `&&` `||` `!`, and stores the collection in a UTF-8 JSON file with the extension `.pim`. Python 3 and the standard library only. No GUI, no third-party TUI, no recurrence, no network.

## Layout

```
model/                    # required package name; the unit-test surface
view/                     # designed terminal UI and in-process Alarm Alerts
controller/               # one user action → model.PIM
pim.py                    # composition root: python3 pim.py
tests/unit/               # model (100% lines) + controller + view
tests/integration/
tests/e2e/                # includes the scripted demo, test_demo.py
tests/coverage_report.py  # model/ line coverage → docs/deliverables/coverage.txt
hooks/                    # pre-commit: unit + integration + e2e
docs/deliverables/        # sources of the SRS, design, manuals, and both reports
docs/presentation/        # deck source and its build script
docs/_*/                  # supporting material: diagrams, typesetting, video, media
docs/build.sh             # typesets the PDFs into the root
*.pdf                     # the brief and the submitted PDFs
README.md
CLAUDE.md                 # rules for AI agents
```

Run with `python3 pim.py`. Tests: `python3 -m unittest`. Coverage: `python3 tests/coverage_report.py` (must be 100% of `model/`). Enable the commit gate: `git config core.hooksPath hooks`. See the [developer manual](docs/deliverables/DEVELOPER.md) and the [user manual](docs/deliverables/USER.md). Story coverage: [`REQUIREMENTS.md`](docs/deliverables/REQUIREMENTS.md).

## Constraints that affect every commit

- Importable top-level package named `model`
- Standard library only (no pip dependencies)
- Default timezone: Hong Kong Time (`Asia/Hong_Kong`)
- Failed commands do not mutate data, dump a traceback, or exit
- Unit tests target `model/` with `unittest` at 100% line coverage; integration and e2e suites also run under `unittest`; line-coverage report (`COVERAGE_REPORT.pdf`) at the source root

## Submission

One ZIP by **20:00, 20 November 2026**: SRS, design document, source, manuals, ≤4 min system video, requirements coverage table, model tests and coverage report, presentation PDF and ≤5 min recording, Honour Declaration at the ZIP root.

The demo script runs end to end as [`tests/e2e/test_demo.py`](tests/e2e/test_demo.py).
