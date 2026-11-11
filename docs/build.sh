#!/bin/sh
# Typeset the course documents as PDFs. The sources (SRS.md, DESIGN.md,
# USER.md, DEVELOPER.md, REQUIREMENTS.md, coverage.txt) live in
# docs/deliverables/; every PDF is written to the source root:
#
#   SRS.pdf  DESIGN_REPORT.pdf  USER_MANUAL.pdf  DEVELOPER_MANUAL.pdf
#   REQUIREMENTS.pdf  COVERAGE_REPORT.pdf
#
# The brief asks for the requirements coverage report and the line-coverage
# report in the root folder of the source code, so their PDFs sit next to pim.py.
#
# The Markdown files stay the only source of the text. The page design lives
# in docs/_typeset/: template.tex (title page, contents, running headers,
# tables, requirement blocks), filter.lua (turns the Markdown into those LaTeX
# structures), and mermaid.json (diagram theme). Diagram sources are in
# docs/_diagrams/. Title-page details (group number, members) come from
# docs/deliverables/group.yaml.
#
# Documentation tooling only: it is not part of the PIM implementation, so the
# standard-library-only rule does not apply. Needs pandoc 3, XeLaTeX (MacTeX),
# mermaid-cli (mmdc), and Google Chrome for mmdc (override with
# PUPPETEER_EXECUTABLE_PATH). Usage from the repository root:
#
#     sh docs/build.sh            # every document
#     sh docs/build.sh SRS DESIGN # only these (named by their source file)

set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCS="$ROOT/docs/deliverables"
TYPESET="$ROOT/docs/_typeset"
DIAGRAMS="$ROOT/docs/_diagrams"

for tool in pandoc xelatex mmdc python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "build: $tool not found" >&2
        exit 1
    fi
done

BUILD=$(mktemp -d "${TMPDIR:-/tmp}/pim-docs.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/diagrams"

# ------------------------------------------------------------------ diagrams
# mmdc drives a headless browser; reuse the installed Chrome instead of a
# puppeteer download. The diagrams use Source Sans 3 (shipped with TeX Live)
# so they match the document headings; the font is embedded in the CSS.
CHROME=${PUPPETEER_EXECUTABLE_PATH:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
printf '{"executablePath": "%s", "args": ["--no-sandbox"]}\n' "$CHROME" > "$BUILD/puppeteer.json"

SANS=$(dirname "$(kpsewhich SourceSans3-Regular.otf)")
{
    for face in Regular:400 Semibold:600 Bold:700; do
        file=${face%%:*}
        weight=${face##*:}
        printf '@font-face{font-family:"Source Sans 3";font-weight:%s;src:url(data:font/otf;base64,%s) format("opentype");}\n' \
            "$weight" "$(base64 < "$SANS/SourceSans3-$file.otf" | tr -d '\n')"
    done
    cat "$TYPESET/mermaid.css"
} > "$BUILD/diagram-fonts.css"

for src in "$DIAGRAMS"/*.mmd; do
    name=$(basename "$src" .mmd)
    echo "build: diagram $name"
    mmdc -q -p "$BUILD/puppeteer.json" -c "$TYPESET/mermaid.json" -C "$BUILD/diagram-fonts.css" \
        -i "$src" -o "$BUILD/diagrams/$name.pdf" --pdfFit -b white
done

# ------------------------------------------------------------------ documents
# Wrap the plain-text coverage report so it renders as a document.
python3 "$TYPESET/coverage_doc.py" "$DOCS/coverage.txt" "$(date '+%-d %B %Y')" > "$BUILD/coverage.md"

ONLY="$*"

render() {
    # $1 = Markdown source, $2 = output PDF path
    name=$(basename "$1" .md)
    # Optional arguments name the documents to build, e.g. "SRS DESIGN".
    if [ -n "$ONLY" ] && ! printf ' %s ' "$ONLY" | grep -q " $name "; then
        return 0
    fi
    echo "build: $(basename "$2")"
    PIM_BUILD_DIR="$BUILD" pandoc "$1" \
        --from markdown \
        --to latex \
        --template="$TYPESET/template.tex" \
        --lua-filter="$TYPESET/filter.lua" \
        --metadata-file="$DOCS/group.yaml" \
        --resource-path="$BUILD:$DOCS:$ROOT" \
        -o "$BUILD/$name.tex"
    # Three passes: contents, figure list, and the "Page n of N" footer.
    for pass in 1 2 3; do
        if ! (cd "$BUILD" && xelatex -interaction=nonstopmode -halt-on-error "$name.tex" > "$name.out" 2>&1); then
            grep -E '^!' -A4 "$BUILD/$name.log" >&2 || tail -20 "$BUILD/$name.out" >&2
            echo "build: xelatex failed on $name" >&2
            exit 1
        fi
    done
    if grep -q 'Missing character' "$BUILD/$name.log"; then
        echo "build: warning: $name uses characters its fonts lack:" >&2
        grep 'Missing character' "$BUILD/$name.log" | sort -u >&2
    fi
    cp "$BUILD/$name.pdf" "$2"
}

render "$DOCS/SRS.md" "$ROOT/SRS.pdf"
render "$DOCS/DESIGN.md" "$ROOT/DESIGN_REPORT.pdf"
render "$DOCS/USER.md" "$ROOT/USER_MANUAL.pdf"
render "$DOCS/DEVELOPER.md" "$ROOT/DEVELOPER_MANUAL.pdf"
render "$DOCS/REQUIREMENTS.md" "$ROOT/REQUIREMENTS.pdf"
render "$BUILD/coverage.md" "$ROOT/COVERAGE_REPORT.pdf"

echo "build: done"
