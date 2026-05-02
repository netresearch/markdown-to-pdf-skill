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
uv run --with markdown --with weasyprint python3 \
  "${SKILL_DIR}/skills/markdown-to-pdf/scripts/convert.py" \
  README.md RFC-001.md -o build/pdfs/
```

Pass `--css path/to/your.css` to apply your own brand stylesheet (logo, colours, fonts, headers). The shipped `assets/style.css` is intentionally neutral.

## Branded output

Netresearch users: install [`netresearch-branding-skill`](https://github.com/netresearch/netresearch-branding-skill) alongside this one and pass its `assets/markdown-pdf.css` via `--css`.

## License

Code: MIT. Documentation/content: CC-BY-SA-4.0. See `LICENSE-MIT` and `LICENSE-CC-BY-SA-4.0`.
