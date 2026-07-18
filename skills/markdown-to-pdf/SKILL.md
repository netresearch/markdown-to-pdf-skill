---
name: markdown-to-pdf
description: Use when converting one or more Markdown files into PDFs. Triggers on "convert to PDF", "make PDF", "export PDF", "markdown to PDF". Generic conversion via WeasyPrint with a neutral default stylesheet; pass `--css` to apply your own branded styling.
metadata:
  version: "1.3.1"
---

# Markdown to PDF

Convert one or more Markdown files into styled PDFs using [WeasyPrint](https://weasyprint.org/) and the Python `markdown` library. The default styling is neutral; apply your own brand stylesheet via `--css`.

## How to use

Run the conversion script via `uv run`:

```bash
uv run --with markdown --with weasyprint python3 "${SKILL_DIR}/scripts/convert.py" <files...> [-o output_dir] [--css custom.css]
```

`${SKILL_DIR}` is the directory containing this `SKILL.md`. The script resolves `assets/style.css` relative to its own location, so it works at any path.

## Steps

1. Identify target `.md` files from the request. If none specified, look in the current directory and ask which to convert.
2. Run the conversion:

   ```bash
   uv run --with markdown --with weasyprint python3 <skill-dir>/scripts/convert.py file1.md file2.md
   ```

   - Use `-o <dir>` to place PDFs in a specific output directory.
   - Use `--css <path>` to override the default stylesheet (e.g., `netresearch-branding-skill/assets/markdown-pdf.css`).
   - Glob patterns like `*.md` are supported.
3. Report which PDF files were created and where.

## Default styling

The bundled `assets/style.css` provides:
- system fonts (no external font fetches)
- neutral grayscale headers
- monospace code blocks
- A4 page size, sensible margins
- page numbers in footer

## Companion skills

- **`netresearch-branding-skill`** ships a `markdown-pdf.css` brand asset. Netresearch users: install both skills, then pass `--css "$CLAUDE_PLUGIN_ROOT/.../netresearch-branding-skill/.../assets/markdown-pdf.css"`.
- That brand CSS expects two wrapper elements this script does **not** generate: `.page-header` (with an `.header-logo` image) and `.page-footer` (with `.footer-info` / `.footer-page`). Passing `--css` with a branded stylesheet yields a PDF with no logo and no footer — no error, just missing brand elements. For compliant output, build the HTML yourself: wrap the body in the `.page-header` / `.page-footer` divs the CSS expects, then call `weasyprint` directly. See netresearch-branding-skill's `SKILL.md`.

## Known pitfalls

- **Bullet list right after a lead-in line, no blank line between them:** `python-markdown` (unlike CommonMark) starts a list only when a blank line precedes it. `Intro:\n- item` renders as literal `- item` text, not a `<ul>` — silently. Always leave a blank line between a lead-in sentence and its list.
- **Such rendering bugs raise no error and don't affect the exit code.** Before calling a conversion done, render the first page to a PNG (`pymupdf`/`fitz`: `page.get_pixmap(dpi=150).save(...)`) and inspect it — don't trust `✓ converted ... (N KB)` alone.

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
