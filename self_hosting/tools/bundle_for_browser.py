"""Concatenate PatLang libraries into one source text for the in-browser runner.

The browser sandbox has no filesystem, so `include` cannot resolve there. This
inlines the schema libraries in dependency order, drops the include lines and
the comment-only lines (the comments live in the library files), and writes the
result. Running the bundle with a call to zsdemo_run appended must print what
the same call prints with the libraries included; the check below does that.

Usage:
    py -3.11 self_hosting/tools/bundle_for_browser.py [OUTPUT]    (default: stdout)
    py -3.11 self_hosting/tools/bundle_for_browser.py --check     (compare backends of inclusion)
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "self_hosting" / "lib"

# Dependency order: each file only uses names defined above it.
ORDER = [
    "list_copy.patlang",
    "pset.patlang",
    "pmap.patlang",
    "step_match.patlang",
    "schema_bdd.patlang",
    "zs_expr.patlang",
    "zs_schema.patlang",
    "zs_explore.patlang",
    "zs_run.patlang",
    "zs_feature.patlang",
    "zs_refine.patlang",
    "zs_generate.patlang",
    "zs_infer.patlang",
    "zs_demo.patlang",
]

# The interpreter built into the parslow.net page (self_hosting/lib/interp.patlang
# compiled to WebAssembly) has no `object_delete` host function, although the
# native runtime does. The explorer calls it to free its seen-set. In the
# browser bundle only, a function of the same name takes its place and does
# nothing: the set is dropped when the page's process ends, which is the
# lifetime of one run. Adding object_delete to interp.patlang and the WASM
# codegen prelude, then rebuilding the playground WASM, would make this shim
# unnecessary.
SHIM = "make a function called object_delete takes name returns done\n  return true\nend"

INCLUDE = re.compile(r'^\s*include\s+"[^"]+"\s*$')
COMMENT = re.compile(r"^\s*#")


def bundle() -> str:
    parts = [SHIM]
    for name in ORDER:
        text = (LIB / name).read_text(encoding="utf-8").replace("\r\n", "\n")
        kept = [ln for ln in text.split("\n") if not INCLUDE.match(ln) and not COMMENT.match(ln)]
        body = "\n".join(kept).strip("\n")
        parts.append(body)
    return "\n\n".join(parts) + "\n"


SAMPLE = '''let schema_text = "schema Counter
state n
init n = 0
invariant n <= 3
operation Inc()
  ensure n' == n + 1
end
"
zsdemo_run(schema_text, "", 1000)
'''


def check() -> int:
    """The bundle, run alone, must print the same as the libraries with includes."""
    pat = ROOT / "rust-runtime" / "target" / "release" / "pat.exe"
    tmp = ROOT / "self_hosting" / "build"
    a = tmp / "_bundle_check_bundle.patlang"
    b = tmp / "_bundle_check_included.patlang"
    a.write_text(bundle() + SAMPLE, encoding="utf-8")
    b.write_text('include "../lib/zs_demo.patlang"\n' + SAMPLE, encoding="utf-8")
    try:
        out_a = subprocess.run([str(pat), "--ir-run", str(a)], capture_output=True, text=True).stdout
        out_b = subprocess.run([str(pat), "--ir-run", str(b)], capture_output=True, text=True).stdout
    finally:
        a.unlink(missing_ok=True)
        b.unlink(missing_ok=True)
    same = out_a == out_b and "[done] 1" in out_a
    print("bundle and included libraries agree:", same)
    if not same:
        print("--- bundle:\n" + out_a + "--- included:\n" + out_b)
    return 0 if same else 1


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        sys.exit(check())
    text = bundle()
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(text, encoding="utf-8")
        print(f"wrote {len(text)} characters ({text.count(chr(10))} lines) to {sys.argv[1]}")
    else:
        sys.stdout.write(text)
