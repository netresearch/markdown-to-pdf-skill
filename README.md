<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# markdown-to-pdf-skill

Convert Markdown files to styled PDFs using [WeasyPrint](https://weasyprint.org/) and the Python `markdown` library. Generic, brand-neutral default; CSS-overridable for branded output.

## 🔌 Compatibility

Agent Skill following the [open standard](https://agentskills.io). Works with Claude Code, Cursor, GitHub Copilot, and any skills-compatible AI agent.

## Installation

### Via Claude Code Marketplace

```
/plugin install markdown-to-pdf@netresearch-claude-code-marketplace
```

### Via Composer

```bash
composer require netresearch/markdown-to-pdf-skill
```

### npm (Node Projects)

```bash
npm install --save-dev \
  @netresearch/agent-skill-coordinator \
  github:netresearch/markdown-to-pdf-skill
```

Requires [@netresearch/agent-skill-coordinator](https://github.com/netresearch/node-agent-skill-coordinator), which discovers the skill in `node_modules` and registers it in `AGENTS.md` via a `postinstall` hook. For pnpm, also allowlist the coordinator's postinstall:

```json
{
  "pnpm": {
    "onlyBuiltDependencies": ["@netresearch/agent-skill-coordinator"]
  }
}
```

### Manual

Clone and place under your agent's skills directory.

## Usage

```bash
uv run "${SKILL_DIR}/skills/markdown-to-pdf/scripts/convert.py" \
  README.md RFC-001.md -o build/pdfs/
```

The Python dependencies (`markdown`, `weasyprint`) are declared as [inline script metadata](https://packaging.python.org/en/latest/specifications/inline-script-metadata/) at the top of `convert.py`; `uv run` installs them. WeasyPrint also needs the Pango system libraries ([installation notes](https://doc.courtbouillon.org/weasyprint/stable/first_steps.html)).

Pass `--css path/to/your.css` to apply your own brand stylesheet (logo, colours, fonts, headers). The shipped `assets/style.css` is intentionally neutral.

Images, stylesheets and fonts are loaded only over `https:` and `data:` URLs. A reference to any other scheme (`http:`, `file:`, `ftp:`) stops the conversion unless that scheme is allowed with `--allow-scheme <scheme>`.

## Branded output

Netresearch users: install [`netresearch-branding-skill`](https://github.com/netresearch/netresearch-branding-skill) alongside this one and pass its `assets/markdown-pdf.css` via `--css`.

## Security

[docs/SECURITY-ASSURANCE.md](docs/SECURITY-ASSURANCE.md) describes the trust boundaries, which resources a conversion may load, the checks that enforce this, and what you cannot expect from the converter. Report vulnerabilities as described in the organisation's [security policy](https://github.com/netresearch/.github/blob/main/SECURITY.md).

## Dependencies

- **Python packages**: `markdown` and `weasyprint`, declared with lower bounds in the inline script metadata of `skills/markdown-to-pdf/scripts/convert.py`. `uv run` installs them from PyPI into a cached environment; there is no lock file.
- **System libraries**: WeasyPrint needs Pango. `.github/workflows/smoke-test.yml` installs it with `apt-get` before running `tests/convert.sh`.
- **Tooling**: GitHub Actions (pinned by commit SHA) and pre-commit hooks (pinned by `rev`) are updated by Renovate (`renovate.json`).

## Governance and policies

- [Governance](https://github.com/netresearch/.github/blob/main/GOVERNANCE.md): who decides, how changes are accepted and how disputes are resolved.
- [Roadmap](https://github.com/netresearch/.github/blob/main/ROADMAP.md): planned and excluded work for the coming year.
- [Handling of dependency and code analysis findings](https://github.com/netresearch/.github/blob/main/SECURITY.md#handling-of-dependency-and-code-analysis-findings): thresholds, deadlines and exceptions for vulnerability and static-analysis findings.
- [Secret management](https://github.com/netresearch/.github/blob/main/SECURITY.md#secret-management): how CI and release credentials are stored, accessed and rotated.
- [Access roster](https://github.com/netresearch/.github/blob/main/docs/access-roster.md): who holds admin and write access to this repository.

Checks that run on every pull request here: Skill Validation (`lint.yml`: skill structure, markdownlint, yamllint, actionlint, JSON syntax, ShellCheck at `style`, ruff), Eval Validation (`eval-validate.yml`), the convert.py smoke test (`smoke-test.yml`), and CodeQL analysis of the Python and GitHub Actions code and SonarCloud, which are configured outside this repository's workflows.

## License

Code: MIT. Documentation/content: CC-BY-SA-4.0. See `LICENSE-MIT` and `LICENSE-CC-BY-SA-4.0`.
