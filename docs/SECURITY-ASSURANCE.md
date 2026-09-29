<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Security assurance case

This document states what `markdown-to-pdf-skill` does to keep a conversion safe, what it does not do, and where each claim can be checked. Vulnerabilities are reported through the process in the organisation's [security policy](https://github.com/netresearch/.github/blob/main/SECURITY.md).

## What the project ships

| Component | File | Role |
| --- | --- | --- |
| Skill instructions | `skills/markdown-to-pdf/SKILL.md` | Tells an AI agent when and how to run the converter |
| Converter | `skills/markdown-to-pdf/scripts/convert.py` | Reads Markdown files, renders them to HTML with `markdown`, and to PDF with WeasyPrint |
| Default stylesheet | `skills/markdown-to-pdf/assets/style.css` | Neutral page and text styling; references no external resource |
| Smoke test | `tests/convert.sh` | Runs the converter and checks the produced PDF and the refusals described below |

The converter's Python dependencies are `markdown` and `weasyprint`, declared in the inline script metadata at the top of `convert.py` and installed by `uv run`. It starts no subprocess and evaluates no code.

## Actors and data flow

- **Operator**: the person, or the agent acting for them, who runs `convert.py`. The operator chooses the input paths or glob patterns, the output directory (`-o`), the stylesheet (`--css`) and any extra URL scheme (`--allow-scheme`).
- **Document author**: whoever wrote the Markdown. This may be someone other than the operator, for example the sender of a file.
- **Remote servers**: hosts that a document or stylesheet references by URL.

Flow in `convert.py`: the command-line arguments are expanded with `glob.glob`; each input file is read as text, converted to HTML by `markdown.markdown` with the `tables`, `fenced_code` and `toc` extensions, wrapped in a fixed HTML skeleton, and passed to WeasyPrint together with the stylesheet. WeasyPrint loads the images, stylesheets and fonts that the HTML and the stylesheet reference through the converter's URL fetcher and writes one PDF per input file, next to the input or into the `-o` directory.

## Trust boundaries

1. **Document content is untrusted.** `markdown.markdown` passes raw HTML in the Markdown through unchanged, so a document can contain any HTML element and inline CSS. The converter does not sanitise it; the controls below limit what that HTML can make the converter do.
2. **Resource URLs cross the network boundary.** Every URL that WeasyPrint wants to load, from the document or from the `--css` stylesheet, goes through `SchemeRestrictedFetcher` in `convert.py`.
3. **Command-line arguments and the `--css` file are trusted.** They come from the operator. The converter reads whatever paths the operator names and writes PDFs where the operator says, replacing an existing PDF of the same name.

## Security requirements and how they are met

| Requirement | How it is met | Evidence |
| --- | --- | --- |
| A document cannot make the converter use an unencrypted or local transport | `SchemeRestrictedFetcher.fetch` accepts only `https:` and `data:` URLs (`DEFAULT_SCHEMES`). Any other scheme (`http:`, `ftp:`, `file:`) raises `FatalURLFetchingError`. The same fetcher is passed to `HTML()` and to `CSS()`, so the `--css` stylesheet is covered too | `convert.py`; `tests/convert.sh` checks that an `http:` image, a `file:` image and an `http:` `@import` in `--css` are refused and that no request reaches the local test server |
| A redirect cannot leave the allowed schemes | WeasyPrint's `URLFetcher.open`, which the redirect handler calls, passes every redirect target back through `fetch` | `tests/convert.sh` ("a redirect to ftp" is refused) |
| A refused resource is not dropped silently | `FatalURLFetchingError` is not caught by WeasyPrint; `convert.py` catches it, prints `refused to load <url>` to stderr, exits with status 1 and writes no PDF | `tests/convert.sh` checks exit code, message and the absence of the PDF |
| Relaxing the rule is an explicit operator decision | `--allow-scheme <scheme>` adds a scheme for one run; there is no configuration file or environment variable that changes the default | `convert.py` `main()`; `tests/convert.sh` ("--allow-scheme http permits the http image") |
| Relative paths do not reach the file system | The HTML is passed as a string without a base URL, so WeasyPrint does not resolve relative references such as `![logo](logo.png)` | `convert.py` (`HTML(string=..., url_fetcher=...)` without `base_url`) |
| Errors are visible | A missing `--css` file and an input pattern that matches nothing both exit with status 1 and a message instead of falling back | `convert.py` `convert()`; `tests/convert.sh` |

## Secure design principles applied

- **Fail-safe defaults**: the scheme allowlist is closed; only `https` and `data` are open without an opt-in.
- **Fail loudly**: a refused URL, a missing stylesheet and an empty input match stop the run with a non-zero exit status rather than producing a PDF that looks correct.
- **Economy of mechanism**: one script of about 170 lines, two direct dependencies, no subprocesses, no dynamic code evaluation.
- **Complete mediation**: every resource load, including redirects and stylesheet imports, goes through one `fetch` method.

## Common weaknesses

| Weakness | Status |
| --- | --- |
| CWE-319 Cleartext transmission | Countered: `http:` and `ftp:` are refused unless allowed with `--allow-scheme` |
| CWE-73 / CWE-22 External control of file names and paths | Countered for document content: `file:` URLs are refused and relative references are not resolved. Paths given on the command line are the operator's choice |
| CWE-918 Server-side request forgery | Partly countered: only `https:` requests are possible by default. HTTPS URLs to any host the machine can reach are still fetched (see limitations) |
| CWE-78 OS command injection, CWE-94 code injection | Not applicable: `convert.py` starts no process and evaluates no code; WeasyPrint does not execute JavaScript ([WeasyPrint documentation, "Going further"](https://doc.courtbouillon.org/weasyprint/stable/going_further.html)) |
| CWE-400 Uncontrolled resource consumption | Not countered: there is no limit on input size, page count or the size of fetched resources. WeasyPrint's fetcher applies a 10-second timeout per request |

## What users can and cannot expect

You can expect that:

- a conversion loads resources only over `https:` and `data:` unless you pass `--allow-scheme`;
- a refused resource stops the conversion with the URL named in the error;
- the converter reads only the input files and the stylesheet you name, plus the resources described above.

You cannot expect that:

- the converter sanitises the document: raw HTML and CSS in the Markdown shape the PDF, and the PDF can contain links and text the author chose;
- HTTPS requests are restricted: a document can reference HTTPS URLs on any host, including hosts on your internal network, and the converter will request them and embed images, stylesheets and fonts it receives. Convert documents from untrusted sources where outbound network access is restricted;
- resource use is bounded: a very large or complex document can take a long time and much memory to render;
- dependency versions are fixed: `uv run` installs the newest `markdown` and `weasyprint` releases that satisfy the lower bounds in `convert.py`; there is no lock file. WeasyPrint's system libraries (Pango) come from the operating system.
