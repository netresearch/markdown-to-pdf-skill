<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# markdown-to-pdf-skill

Agent skill that converts Markdown files to styled PDFs with WeasyPrint and the Python `markdown` library. The skill is text plus one executable, `skills/markdown-to-pdf/scripts/convert.py`.

## Repo Structure

```
skills/markdown-to-pdf/
  SKILL.md                  skill definition and trigger description
  scripts/convert.py        the converter (dependencies are inline script metadata, run with uv)
  assets/style.css          neutral default stylesheet
tests/convert.sh            smoke test for convert.py
evals/evals.json            eval cases for the skill's answers
docs/SECURITY-ASSURANCE.md  trust boundaries and what the converter loads
plugin.json                 Agent Plugins manifest
.claude-plugin/plugin.json  Claude Code manifest; shared fields must match plugin.json
composer.json, package.json distribution metadata (Composer, npm)
.github/workflows/          CI callers of reusable workflows
```

## Commands

- Convert: `uv run skills/markdown-to-pdf/scripts/convert.py README.md -o build/pdfs/`
- Smoke test: `bash tests/convert.sh` (needs `uv` and the Pango system libraries; it skips with exit 0 when `uv` is missing)
- Hooks and linters: `pre-commit install --install-hooks`, then `pre-commit run --all-files`

## Rules

- Licensing is split: code, configuration and workflows are MIT ([LICENSE-MIT](LICENSE-MIT)); documentation and skill content are CC-BY-SA-4.0 ([LICENSE-CC-BY-SA-4.0](LICENSE-CC-BY-SA-4.0)).
- Keep `plugin.json` and `.claude-plugin/plugin.json` in step; Skill Validation fails when the shared fields differ.
- `convert.py` loads images, stylesheets and fonts only over `https:` and `data:` URLs; see [docs/SECURITY-ASSURANCE.md](docs/SECURITY-ASSURANCE.md) before changing that.
- The workflow files that also exist in the `skill` template of `netresearch/.github` are governed by it; `.github/template.yaml` lists the intentional exceptions (`lint.yml`, `release.yml`). `smoke-test.yml` is not a template file.
- Every commit needs a `Signed-off-by` trailer (`git commit -s`) and a signature; branch protection on `main` requires signed commits and the DCO check.

## References

- [README.md](README.md): installation, usage, checks that run on pull requests
- [skills/markdown-to-pdf/SKILL.md](skills/markdown-to-pdf/SKILL.md): skill content
