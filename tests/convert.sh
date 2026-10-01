#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH

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
    # Plain `uv run <script>`: the dependencies come from the inline metadata
    # block in convert.py, so a missing or wrong declaration fails here.
    (cd "$WORK" && uv run "$SCRIPT" "$@" 2>&1)
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

# --- Resource URLs: only https and data unless --allow-scheme ----------------
# A local HTTP server records every request, so "refused" is measured as "no
# request arrived", not inferred from the exit code alone. /redirect answers
# with a redirect to ftp: to check that a redirect cannot leave the allowlist.
cat > "$WORK/server.py" <<'EOF'
import base64, http.server, sys
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        with open(sys.argv[2], "a") as log:
            log.write(self.path + "\n")
        if self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "ftp://127.0.0.1/pixel.png")
            self.end_headers()
            return
        if self.path.startswith("/redirect-to/"):
            self.send_response(302)
            self.send_header("Location", self.path[len("/redirect-to/"):])
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.end_headers()
        self.wfile.write(PNG)
    def log_message(self, *args):
        pass
server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
EOF
: > "$WORK/requests.log"
python3 "$WORK/server.py" "$WORK/port" "$WORK/requests.log" &
SRV=$!
trap 'kill "$SRV" 2>/dev/null; rm -rf "$WORK"' EXIT
for _ in $(seq 50); do [ -s "$WORK/port" ] && break; sleep 0.1; done
PORT="$(cat "$WORK/port")"
BASE="http://127.0.0.1:$PORT"
PIXEL="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
base64 -d <<< "${PIXEL#data:image/png;base64,}" > "$WORK/pixel.png"

refused() { # refused <name> <markdown file> <url> [extra args...]
    local name="$1" md="$2" url="$3"
    shift 3
    : > "$WORK/requests.log"
    rm -f "$WORK/${md%.md}.pdf"
    out=$(run_convert "$md" "$@")
    check "$name: exits non-zero" 1 "$?"
    case "$out" in
        *"refused to load $url"*) echo "  ok   $name: the refused URL is named" ;;
        *) echo "  FAIL $name: the refused URL is named: got '$out'"; fail=1 ;;
    esac
    check "$name: no PDF is written" "no" \
        "$([ -f "$WORK/${md%.md}.pdf" ] && echo yes || echo no)"
}

printf '# Remote\n\n<img src="%s/plain.png">\n' "$BASE" > "$WORK/http-img.md"
refused "an http image" http-img.md "$BASE/plain.png"
check "an http image: no request reaches the server" "" "$(cat "$WORK/requests.log")"

printf '# Local\n\n<img src="file://%s/pixel.png">\n' "$WORK" > "$WORK/file-img.md"
refused "a file: image" file-img.md "file://$WORK/pixel.png"

printf '@import url("%s/imported.css");\n' "$BASE" > "$WORK/import.css"
printf '# Styled\n' > "$WORK/styled.md"
refused "an http @import in --css" styled.md "$BASE/imported.css" --css "$WORK/import.css"
check "an http @import in --css: no request reaches the server" "" "$(cat "$WORK/requests.log")"

printf '# Inline\n\n<img src="%s">\n' "$PIXEL" > "$WORK/data-img.md"
out=$(run_convert data-img.md)
check "a data: image is allowed by default" 0 "$?"

: > "$WORK/requests.log"
out=$(run_convert http-img.md --allow-scheme http)
check "--allow-scheme http permits the http image" 0 "$?"
check "--allow-scheme http: the request reaches the server" "/plain.png" "$(cat "$WORK/requests.log")"

printf '# Redirect\n\n<img src="%s/redirect">\n' "$BASE" > "$WORK/redirect.md"
refused "a redirect to ftp" redirect.md "ftp://127.0.0.1/pixel.png" --allow-scheme http

# WeasyPrint catches errors while it draws an SVG, so a refused resource
# inside an SVG must still fail the conversion rather than vanish.
printf '# SVG\n\n<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="10" height="10"><image href="%s/svg.png" width="10" height="10"/></svg>\n' "$BASE" > "$WORK/svg-img.md"
refused "an http image inside an inline SVG" svg-img.md "$BASE/svg.png"
check "an http image inside an inline SVG: no request reaches the server" "" "$(cat "$WORK/requests.log")"

# A refused redirect target must not be sent by the next fetch. Inside an SVG
# WeasyPrint swallows the refusal and goes on to the next image; a listener on
# the refused target's port records any connection.
cat > "$WORK/listener.py" <<'EOF'
import socket, sys
s = socket.socket()
s.bind(("127.0.0.1", 0))
s.listen(5)
with open(sys.argv[1], "w") as f:
    f.write(str(s.getsockname()[1]))
while True:
    conn, _ = s.accept()
    with open(sys.argv[2], "a") as log:
        log.write("connect\n")
    conn.close()
EOF
: > "$WORK/listener.log"
python3 "$WORK/listener.py" "$WORK/lport" "$WORK/listener.log" &
LSN=$!
trap 'kill "$SRV" "$LSN" 2>/dev/null; rm -rf "$WORK"' EXIT
for _ in $(seq 50); do [ -s "$WORK/lport" ] && break; sleep 0.1; done
FTP_URL="ftp://127.0.0.1:$(cat "$WORK/lport")/pixel.png"
printf '# SVG redirect\n\n<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="%s/redirect-to/%s" width="10" height="10"/></svg>\n\n<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="%s" width="10" height="10"/></svg>\n' "$BASE" "$FTP_URL" "$PIXEL" > "$WORK/svg-redirect.md"
refused "a redirect to ftp inside an SVG" svg-redirect.md "$FTP_URL" --allow-scheme http
check "a redirect to ftp inside an SVG: the refused target is never contacted" "" "$(cat "$WORK/listener.log")"

echo ""
if [ "$fail" -eq 0 ]; then
    echo "All convert.py smoke tests passed"
else
    echo "convert.py smoke tests FAILED"
fi
exit "$fail"
