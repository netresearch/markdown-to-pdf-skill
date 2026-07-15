---
name: markdown-to-pdf
description: Use when converting one or more Markdown files into PDFs. Triggers on "convert to PDF", "make PDF", "export PDF", "markdown to PDF". Generic conversion via WeasyPrint with a neutral default stylesheet; pass `--css` to apply your own branded styling.
metadata:
  version: "1.3.1"
---

# Markdown to PDF

Convert one or more Markdown files into styled PDFs using [WeasyPrint](https://weasyprint.org/) and the Python `markdown` library. The default styling is intentionally neutral — apply your own brand stylesheet via `--css`.

## How to use

Run the conversion script via `uv run`:

```bash
uv run --with markdown --with weasyprint python3 "${SKILL_DIR}/scripts/convert.py" <files...> [-o output_dir] [--css custom.css]
```

`${SKILL_DIR}` is the directory containing this `SKILL.md`. The script resolves `assets/style.css` relative to its own location, so it works regardless of install path.

## Steps

1. Identify target `.md` files from the user's request. If none specified, look for `.md` files in the current directory and ask which to convert.
2. Run the conversion:

   ```bash
   uv run --with markdown --with weasyprint python3 <skill-dir>/scripts/convert.py file1.md file2.md
   ```

   - Use `-o <dir>` to place PDFs in a specific output directory.
   - Use `--css <path>` to override the default neutral stylesheet (e.g., a brand stylesheet from `netresearch-branding-skill/assets/markdown-pdf.css`).
   - Glob patterns like `*.md` are supported.
3. Report which PDF files were created and their locations.

## Default styling

The bundled `assets/style.css` provides:
- system fonts (no external font fetches)
- neutral grayscale headers
- printable code blocks with monospace font
- A4 page size with sensible margins
- page numbers in footer

For branded output, supply a `--css` value pointing at your organisation's stylesheet (logo, colours, fonts, headers).

## Companion skills

- **`netresearch-branding-skill`** ships a `markdown-pdf.css` brand asset. Internal Netresearch users: install both skills, then `--css "$(echo $CLAUDE_PLUGIN_ROOT/.../netresearch-branding-skill/.../assets/markdown-pdf.css)"`.
- That brand CSS expects two wrapper elements this script does **not** generate on its own: `.page-header` (containing an `.header-logo` image) and `.page-footer` (containing `.footer-info` / `.footer-page`). Passing `--css` alone with a branded stylesheet produces a PDF with no logo and no footer — no error, just missing brand elements. To get compliant branded output, build the HTML yourself (parse the Markdown, wrap the body in `<div class="page-header">...</div>` / `<div class="page-footer">...</div>` with the classes the target CSS expects, then call `weasyprint` directly) instead of relying on this script's `--css` flag alone. See netresearch-branding-skill's `SKILL.md` for the exact required elements.

## Known pitfalls

- **Bullet list right after a lead-in line, no blank line between them:** `python-markdown` (unlike CommonMark) does not start a new list unless a blank line precedes it. `Intro:\n- item` renders as literal `- item` text, not a `<ul>` — silently, with no error. Always leave a blank line between a lead-in sentence and the list that follows it.
- **Rendering bugs like the one above raise no error and don't show in the exit code.** Before treating a conversion as done, render at least the first page to a PNG (e.g. `pymupdf`/`fitz`: `page.get_pixmap(dpi=150).save(...)`) and look at it, rather than trusting `✓ converted ... (N KB)` alone.

## Output format

Per file:

```
✓ converted README.md → README.pdf (12.3 KB)
✓ converted RFC-001.md → RFC-001.pdf (4.7 KB)
```

## Errors

| Error | Action |
|-------|--------|
| No `.md` files matched | List directory contents and ask user |
| WeasyPrint missing | `uv run` should auto-resolve it; if not, suggest `uv pip install weasyprint` |
| `--css` file not found | Surface the missing path; do not fall back silently |
