#!/usr/bin/env python3
"""Transcribe the runtime prelude (Rust text) into PatLang source.

Reads self_hosting/runtime/prelude.rs and writes
self_hosting/lib/runtime_rs.patlang: a PatLang module whose
emit_runtime_rs() reproduces the prelude byte-for-byte via string-builder
pushes. Quotes and backslashes are emitted through q()/bs() helpers so the
generated PatLang parses identically under the Stage 0 lexer (which decodes
escapes) and the Stage 1 self-hosted lexer (which does not).

Regeneration flow after changing the host codegen template:
  pat --ir-run self_hosting/tools/dump_prelude.patlang
  python self_hosting/tools/transcribe_prelude.py
"""

import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRELUDE = os.path.join(ROOT, "runtime", "prelude.rs")
OUT = os.path.join(ROOT, "lib", "runtime_rs.patlang")
CHUNK = 100  # lines per emitter function


def encode_line(line: str) -> str:
    """PatLang expression reproducing `line` exactly (no trailing newline)."""
    parts = []
    seg = []

    def flush():
        if seg:
            parts.append('"' + "".join(seg) + '"')
            seg.clear()

    for ch in line:
        if ch == '"':
            flush()
            parts.append("q()")
        elif ch == "\\":
            flush()
            parts.append("bs()")
        elif ch == "\t":
            flush()
            parts.append("tab()")
        else:
            seg.append(ch)
    flush()
    if not parts:
        return '""'
    return " + ".join(parts)


def main() -> None:
    text = open(PRELUDE, encoding="utf-8", newline="").read()
    # prelude is LF-delimited; keep exact reproduction including final newline
    assert "\r" not in text, "prelude must be LF-only"
    lines = text.split("\n")
    trailing_newline = lines and lines[-1] == ""
    if trailing_newline:
        lines = lines[:-1]

    out = io.StringIO()
    out.write(
        "# =============================================================================\n"
        "# GENERATED FILE - do not edit by hand.\n"
        "# The runtime prelude embedded in every emitted program, expressed as\n"
        "# PatLang source. Regenerate after changing the host codegen template:\n"
        "#   pat --ir-run self_hosting/tools/dump_prelude.patlang\n"
        "#   python self_hosting/tools/transcribe_prelude.py\n"
        "# emit_runtime_rs() reproduces runtime/prelude.rs byte-for-byte\n"
        "# (parity-checked against codegen_prelude() by the test suite).\n"
        "# =============================================================================\n"
        "\n"
        "make a function called bs returns s\n"
        "  return chr(92)\n"
        "end\n"
        "\n"
        "make a function called tab returns s\n"
        "  return chr(9)\n"
        "end\n"
    )

    chunks = [lines[i:i + CHUNK] for i in range(0, len(lines), CHUNK)]
    for ci, chunk in enumerate(chunks):
        out.write(f"\nmake a function called emit_runtime_rs_{ci} takes b returns done\n")
        for line in chunk:
            out.write(f"  sb_push(b, {encode_line(line)} + nl())\n")
        out.write("  return true\nend\n")

    out.write("\nmake a function called emit_runtime_rs returns s\n")
    out.write("  let b = sb_new()\n")
    for ci in range(len(chunks)):
        out.write(f"  emit_runtime_rs_{ci}(b)\n")
    out.write("  return sb_str(b)\nend\n")

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(out.getvalue())
    print(f"wrote {OUT}: {len(lines)} prelude lines in {len(chunks)} chunks")


if __name__ == "__main__":
    main()
