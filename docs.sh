#!/usr/bin/env bash
# Builds the documentation site: the pages in docs/ plus the API reference that
# pony-doc generates from the docstrings.
#
#   ./docs.sh            build into site/
#   ./docs.sh --serve    serve it on http://127.0.0.1:8000
#
# Needs ponyc (which ships pony-doc), corral, and mkdocs with the material
# theme: pip install mkdocs-material
set -euo pipefail

api_pages=docs/api
work=build/pony-doc

rm -rf "$api_pages" "$work"
mkdir -p "$api_pages" "$work"

# corral puts the dependencies on the module search path, as it does for ponyc.
corral run -- pony-doc -o "$work" erl_interface_pony

# The generated pages link to the standard library types they mention and to
# the sources they came from, so the whole tree comes along; the pages the
# navigation lists are the ones written by hand.
cp -R "$work/erl_interface_pony-docs/docs/." "$api_pages/"
rm -rf "$work"

if [ "${1:-}" = "--serve" ]; then
  exec mkdocs serve
fi

mkdocs build
