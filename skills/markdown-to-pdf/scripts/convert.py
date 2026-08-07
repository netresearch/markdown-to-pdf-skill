#!/usr/bin/env python3
"""Convert Markdown files to styled PDFs using weasyprint + markdown.

Generic, brand-neutral. For Netresearch-branded output, pass
`--css path/to/netresearch-branding-skill/assets/markdown-pdf.css`.
"""

import argparse
import glob
import os
import sys
from pathlib import Path

import markdown
from weasyprint import CSS, HTML

SKILL_DIR = Path(__file__).resolve().parent.parent
DEFAULT_CSS = SKILL_DIR / "assets" / "style.css"


def convert(
    input_files: list[str],
    output_dir: str | None = None,
    css_path: str | None = None,
) -> list[Path]:
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

        HTML(string=html_doc).write_pdf(target=str(dst), stylesheets=[CSS(string=css)])
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
    args = parser.parse_args()
    convert(args.input_files, args.output_dir, args.css)


if __name__ == "__main__":
    main()
