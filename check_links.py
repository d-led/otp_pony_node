#!/usr/bin/env python3
"""Checks the links of the built documentation site.

Reads `site/` after `mkdocs build`, so the anchors it checks are the ones the
pages really carry: the id of a source line exists only once the page has been
rendered, which is why mkdocs' own anchor check cannot see it and is turned off
in `mkdocs.yml`.

Exits non-zero and names the page, the link and what was missing.
"""
import pathlib
import re
import sys
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent
SITE = ROOT / "site"

LINK = re.compile(r'href="([^"]+)"')
IDENTIFIER = re.compile(r'\bid="([^"]+)"|\bname="([^"]+)"')


def base_path():
    """The path the site is published under, as `site_url` in mkdocs.yml says.

    Material's 404 page links from the root of that path, so those links only
    resolve once the path is taken off them.
    """
    settings = (ROOT / "mkdocs.yml").read_text()
    published = re.search(r"^site_url:\s*(\S+)", settings, re.M)
    return urllib.parse.urlparse(published.group(1)).path if published else "/"


def target_of(page, href):
    """The file a link opens, or None when it is not a link inside the site."""
    if href.startswith(("http://", "https://", "//", "mailto:")):
        return None

    path, _, anchor = href.partition("#")
    path = urllib.parse.unquote(path)
    anchor = urllib.parse.unquote(anchor)

    if path == "":
        return page, anchor

    if path.startswith("/"):
        base = base_path()
        path = path[len(base):] if base != "/" and path.startswith(base) else path[1:]
        wanted = (SITE / path).resolve()
    else:
        wanted = (page.parent / path).resolve()

    if wanted.is_dir():
        wanted = wanted / "index.html"
    elif not wanted.suffix:
        wanted = wanted / "index.html"
    return wanted, anchor


def identifiers(path):
    return {
        found
        for pair in IDENTIFIER.findall(path.read_text(errors="replace"))
        for found in pair
        if found
    }


def main():
    if not SITE.is_dir():
        print("site/ is not there: run ./docs.sh, which builds it before this", file=sys.stderr)
        return 2

    pages = sorted(SITE.rglob("*.html"))
    broken = 0
    checked = 0

    for page in pages:
        for href in LINK.findall(page.read_text(errors="replace")):
            found = target_of(page, href)
            if found is None:
                continue
            target, anchor = found
            checked += 1

            if not target.is_file():
                print(f"{page.relative_to(SITE)}: {href} -> no such page")
                broken += 1
            elif anchor and anchor not in identifiers(target):
                print(f"{page.relative_to(SITE)}: {href} -> no such anchor")
                broken += 1

    print(f"\n{checked} links checked over {len(pages)} pages, {broken} broken")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
