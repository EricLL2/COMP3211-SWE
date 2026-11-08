# COMP3211 PIM

Command-line Personal Information Management system for PolyU COMP3211 Software Engineering (Fall 2026).

The assignment brief is [`docs/Project Description.pdf`](<docs/Project Description.pdf>). Requirements are specified in the SRS and the design, with its decisions, in the design document. Implementation must follow those files, not reopen them.

## Documents

Every document lives under `docs/`, except this README, `CLAUDE.md`, and the two reports the brief requires in the root folder of the source code (`REQUIREMENTS.md` and `coverage.txt`). Each graded document is written in Markdown and typeset as a PDF next to it (`sh docs/deliverables/build.sh`).

| Source | PDF | What it is |
|---|---|---|
| [`docs/deliverables/SRS.md`](docs/deliverables/SRS.md) | [`SRS.pdf`](docs/deliverables/SRS.pdf) | Software requirements specification (deliverable 1): scope, glossary, every functional and non-functional requirement |
| [`docs/deliverables/DESIGN.md`](docs/deliverables/DESIGN.md) | [`DESIGN.pdf`](docs/deliverables/DESIGN.pdf) | Design document (deliverable 2): MVC architecture, classes, PIM File format, search-then-update sequence; §5 records the design decisions |
| [`docs/deliverables/USER.md`](docs/deliverables/USER.md) | [`USER.pdf`](docs/deliverables/USER.pdf) | User manual |
| [`docs/deliverables/DEVELOPER.md`](docs/deliverables/DEVELOPER.md) | [`DEVELOPER.pdf`](docs/deliverables/DEVELOPER.pdf) | Developer manual |
| [`REQUIREMENTS.md`](REQUIREMENTS.md) | [`REQUIREMENTS.pdf`](REQUIREMENTS.pdf) | Requirements coverage report (source root, as the brief requires) |
| `coverage.txt` | [`coverage.pdf`](coverage.pdf) | `model/` line coverage, written by `coverage_report.py` (source root, as the brief requires) |
| [`docs/presentation/`](docs/presentation/) | [`PIM-presentation.pdf`](docs/presentation/PIM-presentation.pdf) | Presentation deck (`PIM-presentation.pptx`) with speaker notes (deliverable 5) |
| [`docs/BACKLOG.md`](docs/BACKLOG.md) | — | Open deliverables, demo script, manual checks, known UI gaps, and a log of what landed |
| [`CLAUDE.md`](CLAUDE.md) | — | Rules for AI agents: precedence, scope, architecture, gates |

Use the SRS glossary (§3) terms as written. Do not treat **Name** as a title, **Label** as identity, or **Note** as a field name.

## Product in one paragraph

A single-user terminal PIM. The user manages Notes, Tasks, Events, and Contacts in a Working Collection, searches with contains / time comparison / `&&` `||` `!`, and stores the collection in a UTF-8 JSON file with the extension `.pim`. Python 3 and the standard library only. No GUI, no third-party TUI, no recurrence, no network.

## Layout

```
model/          # required package name; the unit-test surface
view/           # designed terminal UI and in-process Alarm Alerts
controller/     # one user action → model.PIM
pim.py          # composition root: python3 pim.py
tests/unit/     # model (100% lines) + controller + view
tests/integration/
tests/e2e/
hooks/          # pre-commit: unit + integration + e2e
docs/           # brief, SRS, design document, manuals, presentation, backlog
REQUIREMENTS.md # requirements coverage report (brief: source root)
coverage.txt    # model/ line coverage (brief: source root)
README.md
CLAUDE.md       # rules for AI agents
```

Run with `python3 pim.py`. Tests: `python3 -m unittest`. Coverage: `python3 coverage_report.py` (must be 100% of `model/`). Enable the commit gate: `git config core.hooksPath hooks`. See the [developer manual](docs/deliverables/DEVELOPER.md) and the [user manual](docs/deliverables/USER.md). Story coverage: [`REQUIREMENTS.md`](REQUIREMENTS.md).

## Constraints that affect every commit

- Importable top-level package named `model`
- Standard library only (no pip dependencies)
- Default timezone: Hong Kong Time (`Asia/Hong_Kong`)
- Failed commands do not mutate data, dump a traceback, or exit
- Unit tests target `model/` with `unittest` at 100% line coverage; integration and e2e suites also run under `unittest`; line-coverage report at the source root

## Submission

One ZIP by **20:00, 20 November 2026**: SRS, design document, source, manuals, ≤4 min system video, requirements coverage table, model tests and coverage report, presentation PDF and ≤5 min recording, Honour Declaration at the ZIP root.

Open items and the demo script: [`docs/BACKLOG.md`](docs/BACKLOG.md).
