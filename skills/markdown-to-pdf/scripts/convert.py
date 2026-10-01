#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH

# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "markdown>=3.4.4",
#     "weasyprint>=68",
# ]
# ///
"""Convert Markdown files to styled PDFs using weasyprint + markdown.

Generic, brand-neutral. For Netresearch-branded output, pass
`--css path/to/netresearch-branding-skill/assets/markdown-pdf.css`.
"""

import argparse
import glob
import os
import sys
import uuid
from pathlib import Path
from urllib.parse import urlsplit

import markdown
from weasyprint import CSS, HTML
from weasyprint.urls import FatalURLFetchingError, URLFetcher

SKILL_DIR = Path(__file__).resolve().parent.parent
DEFAULT_CSS = SKILL_DIR / "assets" / "style.css"

# URL schemes WeasyPrint may load resources (images, stylesheets, fonts,
# attachments) from without an explicit opt-in: https is encrypted and data:
# needs no connection. Everything else -- http, ftp, file -- is refused unless
# the caller names it with --allow-scheme.
DEFAULT_SCHEMES = frozenset({"https", "data"})


class SchemeRestrictedFetcher(URLFetcher):
    """URL fetcher that refuses every scheme outside an allowlist.

    The refusal raises FatalURLFetchingError, which stops the conversion for
    resources of the document and its stylesheets. WeasyPrint catches errors
    while it draws an SVG image, so a resource referenced from inside an SVG
    would otherwise be dropped silently; every refusal is therefore also
    recorded in `refused`, and convert() fails the file when the list is not
    empty after rendering. Redirects re-enter fetch() through
    URLFetcher.open(), so a redirect to a refused scheme is refused as well.
    """

    def __init__(self, allowed_schemes: frozenset[str]) -> None:
        super().__init__()
        self.allowed_schemes = allowed_schemes
        self.refused: list[str] = []

    def fetch(self, url, headers=None):
        scheme = urlsplit(url).scheme.lower()
        if scheme not in self.allowed_schemes:
            allowed = ", ".join(sorted(self.allowed_schemes))
            message = (
                f"refused to load {url}: scheme '{scheme}' is not allowed "
                f"(allowed: {allowed}; add one with --allow-scheme)"
            )
            self.refused.append(message)
            # URLFetcher.open() parks a redirect's request in _request and
            # fetch() sends a parked request instead of the URL it is given.
            # Drop it, or the next allowed fetch would send the refused one
            # (WeasyPrint catches the refusal while drawing an SVG and goes on).
            self._request = None
            raise FatalURLFetchingError(message)
        return super().fetch(url, headers)


def convert(
    input_files: list[str],
    output_dir: str | None = None,
    css_path: str | None = None,
    allow_schemes: list[str] | None = None,
) -> list[Path]:
    fetcher = SchemeRestrictedFetcher(
        DEFAULT_SCHEMES | {s.lower() for s in allow_schemes or []}
    )
    css_file = Path(css_path) if css_path else DEFAULT_CSS
    if not css_file.exists():
        print(f"Error: CSS file not found: {css_file}", file=sys.stderr)
        sys.exit(1)
    css = css_file.read_text()

    # Expand glob patterns
    resolved: list[str] = []
    for pattern in input_files:
        matches = glob.glob(pattern)
        if matches:
            resolved.extend(matches)
        elif Path(pattern).exists():
            resolved.append(pattern)
        else:
            print(f"Warning: no files matched '{pattern}'", file=sys.stderr)
    if not resolved:
        print("Error: no input files found.", file=sys.stderr)
        sys.exit(1)

    written: list[Path] = []
    for src in resolved:
        src_path = Path(src)
        if not src_path.exists():
            print(f"Skipping {src}: file not found", file=sys.stderr)
            continue

        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
            dst = Path(output_dir) / src_path.with_suffix(".pdf").name
        else:
            dst = src_path.with_suffix(".pdf")

        content = src_path.read_text()
        html_body = markdown.markdown(
            content, extensions=["tables", "fenced_code", "toc"]
        )
        html_doc = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{src_path.stem}</title>
</head>
<body>
{html_body}
</body>
</html>"""

        # Render into a temporary file of its own next to the target, so a
        # refused resource leaves neither a partial PDF nor a replaced older
        # one, and two runs on the same target do not share the file.
        # WeasyPrint creates it like any plain write, so the PDF gets the
        # usual mode (0666 minus the umask).
        tmp = dst.with_name(f".{dst.name}.{uuid.uuid4().hex}.partial")
        fetcher.refused.clear()
        try:
            HTML(string=html_doc, url_fetcher=fetcher).write_pdf(
                target=str(tmp),
                stylesheets=[CSS(string=css, url_fetcher=fetcher)],
            )
        except FatalURLFetchingError as exc:
            tmp.unlink(missing_ok=True)
            print(f"Error: {src_path}: {exc}", file=sys.stderr)
            sys.exit(1)
        if fetcher.refused:
            tmp.unlink(missing_ok=True)
            print(f"Error: {src_path}: {fetcher.refused[0]}", file=sys.stderr)
            sys.exit(1)
        tmp.replace(dst)
        size = dst.stat().st_size
        print(f"✓ converted {src_path} → {dst} ({size / 1024:.1f} KB)")
        written.append(dst)
    return written


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert Markdown files to styled PDFs."
    )
    parser.add_argument(
        "input_files",
        nargs="+",
        help="Markdown file paths or glob patterns",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        help="Output directory (default: alongside input file)",
    )
    parser.add_argument(
        "--css",
        help="Path to a custom CSS file (default: assets/style.css)",
    )
    parser.add_argument(
        "--allow-scheme",
        action="append",
        metavar="SCHEME",
        help=(
            "Also load resources over this URL scheme, e.g. http or file "
            "(repeatable; https and data are always allowed)"
        ),
    )
    args = parser.parse_args()
    convert(args.input_files, args.output_dir, args.css, args.allow_scheme)


if __name__ == "__main__":
    main()
