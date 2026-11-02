#!/usr/bin/env python3
"""Compiles the complete ```pony examples in this project's markdown.

A block counts as complete when it declares something at the top level, or is
only a `use` line. Statement fragments are skipped: they lean on names from the
prose around them, so compiling one would check the wrapper and not the page.

Exits non-zero and names the page and line of every example that did not
compile.
"""
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent

PAGES = ["README.md", "CHANGELOG.md"]
BLOCK = re.compile(r"^```pony\n(.*?)^```", re.S | re.M)
DECLARATION = re.compile(r"^(actor|class|primitive|trait|struct) \w+", re.M)
MAIN = re.compile(r"^(actor|class) Main\b", re.M)


def pages():
    root_pages = [ROOT / name for name in PAGES]
    return [page for page in root_pages if page.exists()] + sorted((ROOT / "docs").glob("*.md"))


def blocks():
    for page in pages():
        text = page.read_text()
        for match in BLOCK.finditer(text):
            line = text[: match.start()].count("\n") + 1
            yield page.relative_to(ROOT), line, match.group(1)


def as_program(body):
    """The block as a program that can be compiled, or None for a fragment."""
    lines = body.splitlines(True)
    uses = []
    while lines and lines[0].startswith("use "):
        uses.append(lines.pop(0))
    rest = "".join(lines)

    if not rest.strip() or not DECLARATION.search(rest):
        return None

    program = "".join(uses) + ("\n" if uses else "") + rest
    if not MAIN.search(program):
        # A library example has no entry point of its own; an empty one makes
        # the compiler link it.
        program += "\nactor Main\n  new create(env: Env) => None\n"
    return program


def compile_example(directory, program):
    """The compiler's own words about the example, and whether it built."""
    (directory / "main.pony").write_text(program)
    finished = subprocess.run(
        ["ponyc", "-p", str(ROOT), "-o", str(directory), str(directory)],
        capture_output=True,
        text=True,
    )
    noise = ("Building ", "Writing ", "Linking ", "Generating ")
    report = [
        line
        for line in (finished.stdout + finished.stderr).splitlines()
        if line.strip() and not line.startswith(noise)
    ]
    return finished.returncode == 0, report


def main():
    checked = 0
    fragments = 0
    failed = 0

    with tempfile.TemporaryDirectory() as workspace:
        for index, (page, line, body) in enumerate(blocks(), start=1):
            program = as_program(body)
            if program is None:
                fragments += 1
                continue

            checked += 1
            directory = pathlib.Path(workspace) / f"example{index:02d}"
            directory.mkdir()
            ok, report = compile_example(directory, program)
            print(("ok  " if ok else "no  ") + f"{page}:{line}")
            if not ok:
                failed += 1
                for output in report:
                    print("      " + output)

    print(f"\n{checked} examples compiled, {failed} did not, {fragments} fragments skipped")
    return 1 if failed else 0


if __name__ == "__main__":
    if subprocess.run(["ponyc", "--version"], capture_output=True).returncode != 0:
        print("ponyc is not on the PATH, so the examples cannot be compiled", file=sys.stderr)
        sys.exit(2)
    sys.exit(main())
