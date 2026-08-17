#!/usr/bin/env bash
# tests/convert.sh — smoke test for scripts/convert.py.
#
# The skill's value is an executable: whether the agent describes the right
# command matters less than whether the command produces a PDF. Text evals
# cannot see that, so this asserts the artefact — a file that exists, is
# non-empty, and starts with the PDF magic bytes rather than an HTML error page.
#
# It also pins the one documented failure mode that must NOT degrade quietly: a
# `--css` path that does not exist has to fail loudly instead of falling back to
# the bundled stylesheet, because a silent fallback ships unbranded output that
# looks like success.
#
# Requires uv. Skips with exit 0 when uv is absent, so a machine without it
# reports "skipped" rather than a failure it cannot diagnose.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(cd "$HERE/.." && pwd)/skills/markdown-to-pdf/scripts/convert.py"

if ! command -v uv >/dev/null 2>&1; then
    echo "SKIP: uv not installed — cannot resolve markdown/weasyprint"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0
check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: expected '$2', got '$3'"
        fail=1
    fi
}

run_convert() { # run_convert <args...>
    (cd "$WORK" && uv run --with markdown --with weasyprint python3 "$SCRIPT" "$@" 2>&1)
}

cat > "$WORK/sample.md" <<'EOF'
# Sample

Body text with **bold**, a list:

- one
- two

| a | b |
|---|---|
| 1 | 2 |

```php
echo 'fenced code';
```
EOF

# --- A PDF is produced -------------------------------------------------------
out=$(run_convert sample.md -o out)
rc=$?
check "conversion exits 0" 0 "$rc"
check "a PDF is written to the output directory" "yes" \
    "$([ -f "$WORK/out/sample.pdf" ] && echo yes || echo no)"
size=$(wc -c < "$WORK/out/sample.pdf" 2>/dev/null || echo 0)
check "the PDF is larger than 1 KB" "yes" \
    "$([ "${size:-0}" -gt 1024 ] && echo yes || echo no)"
check "the file really is a PDF, not an HTML error page" "%PDF" \
    "$(head -c 4 "$WORK/out/sample.pdf" 2>/dev/null)"
case "$out" in
    *"converted"*) echo "  ok   the run reports what it converted" ;;
    *) echo "  FAIL the run reports what it converted: got '$out'"; fail=1 ;;
esac

# --- A missing --css must not degrade silently -------------------------------
out=$(run_convert sample.md --css "$WORK/does-not-exist.css")
rc=$?
check "a missing --css path exits non-zero" 1 "$rc"
case "$out" in
    *"CSS file not found"*) echo "  ok   the missing stylesheet is named in the error" ;;
    *) echo "  FAIL the missing stylesheet is named in the error: got '$out'"; fail=1 ;;
esac
check "no PDF is written when the stylesheet is missing" "no" \
    "$([ -f "$WORK/sample.pdf" ] && echo yes || echo no)"

# --- No input match is an error, not an empty success ------------------------
out=$(run_convert "$WORK/nothing-here-*.md")
check "a pattern matching nothing exits non-zero" 1 "$?"
case "$out" in
    *"no input files"*) echo "  ok   the empty match is reported" ;;
    *) echo "  FAIL the empty match is reported: got '$out'"; fail=1 ;;
esac

echo ""
if [ "$fail" -eq 0 ]; then
    echo "All convert.py smoke tests passed"
else
    echo "convert.py smoke tests FAILED"
fi
exit "$fail"
