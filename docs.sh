#!/usr/bin/env bash
# Builds the documentation site: the pages in docs/ plus the API reference that
# pony-doc generates from the docstrings.
#
#   ./docs.sh            build into site/
#   ./docs.sh --serve    serve it on http://127.0.0.1:8000
#
# Needs ponyc (which ships pony-doc), corral, mkdocs with the material theme
# and a python3 to trim the generated tree: pip install mkdocs-material
set -euo pipefail

api_pages=docs/api
work=build/pony-doc

rm -rf "$api_pages" "$work"
mkdir -p "$api_pages" "$work"

# corral puts the dependencies on the module search path, as it does for ponyc.
corral run -- pony-doc -o "$work" erl_interface_pony
cp -R "$work/erl_interface_pony-docs/docs/." "$api_pages/"
rm -rf "$work"

# pony-doc writes a page for every package it type checked, which is the whole
# standard library.  Only this package's pages and sources are published; the
# links that pointed at the others go to stdlib.ponylang.io, which serves the
# same page names.
python3 - "$api_pages" <<'PY'
import pathlib
import re
import shutil
import sys

ours = "erl_interface_pony"
api = pathlib.Path(sys.argv[1])
sources = api / "src" / ours

for path in api.glob("*.md"):
    if not path.name.startswith(ours + "-"):
        path.unlink()

for path in (api / "src").iterdir():
    if path != sources:
        shutil.rmtree(path) if path.is_dir() else path.unlink()

page = re.compile(r"\]\((?!src/)([A-Za-z0-9_+-]+)\.md(#[^)]*)?\)")
source = re.compile(r"\]\(src/([A-Za-z0-9_/+-]+)\.md(#[^)]*)?\)")


def to_stdlib(match, prefix):
    name, anchor = match.group(1), match.group(2) or ""
    return "](" + prefix + name + "/" + anchor + ")"


def rewrite(text):
    def one_page(match):
        name, anchor = match.group(1), match.group(2) or ""
        if name.startswith(ours + "-"):
            return "](" + name + ".md" + anchor + ")"
        return to_stdlib(match, "https://stdlib.ponylang.io/")

    def line_anchor(anchor):
        # pony-doc names a source line `#L-0-<line>`; the ids the built source
        # pages carry come from the line numbers of their one code block.
        found = re.fullmatch(r"#L-0-(\d+)", anchor)
        return "#__codelineno-0-" + found.group(1) if found else anchor

    def one_source(match):
        path, anchor = match.group(1), match.group(2) or ""
        if not path.startswith(ours + "/"):
            return to_stdlib(match, "https://stdlib.ponylang.io/src/")

        name = path.split("/", 1)[1]
        if (sources / (name + ".md")).exists():
            return "](" + "src/" + path + ".md" + line_anchor(anchor) + ")"

        # A member this package inherits gets a source link named after this
        # module and the file that defines it, which is the standard library's.
        return "](https://stdlib.ponylang.io/src/builtin/" + name + "/" + anchor + ")"

    return source.sub(one_source, page.sub(one_page, text))


for path in list(api.glob("*.md")) + list(sources.glob("*.md")):
    path.write_text(rewrite(path.read_text()))
PY

# The examples in the pages are type checked first: a page that shows code the
# package no longer accepts is a broken page, whatever the site looks like.
./check_examples.py

if [ "${1:-}" = "--serve" ]; then
  exec mkdocs serve
fi

mkdocs build

# The links are checked on what was just built: the id of a source line exists
# only after rendering, which is the one thing mkdocs' own anchor check cannot
# see, and it is why that check is turned off in mkdocs.yml.
./check_links.py
