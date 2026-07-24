import re, sys, io

CODEGEN = r"F:\PatLang\rust-runtime\src\ir\codegen.rs"
RUNTIME_RS = r"F:\PatLang\self_hosting\lib\runtime_rs.patlang"

# chunk_name (as used in PARITY-* / codegen_prelude_chunk) -> PRELUDE_<X> const name
CHUNKS = {
    "core": "PRELUDE_CORE",
    "collections_handles": "PRELUDE_COLLECTIONS_HANDLES",
    "files": "PRELUDE_FILES",
    "io_misc": "PRELUDE_IO_MISC",
    "math": "PRELUDE_MATH",
    "logic": "PRELUDE_LOGIC",
    "contracts": "PRELUDE_CONTRACTS",
    "numeric_tower": "PRELUDE_NUMERIC_TOWER",
    "codegen_bootstrap": "PRELUDE_CODEGEN_BOOTSTRAP",
    "networking": "PRELUDE_NETWORKING",
    "oo": "PRELUDE_OO",
    "strings_ext": "PRELUDE_STRINGS_EXT",
    # NOTE: this dict has needed a new entry added reactively FOUR times
    # in one session (collections_handles/io_misc, then math, then
    # networking here) -- each time because a chunk existed in codegen.rs
    # and was checked by selfhost_pipeline.rs's parity test, but simply
    # hadn't been added here yet. oo/strings_ext are added now purely
    # pre-emptively (both already PARITY-OK as of 2026-07-17, not because
    # anything is currently broken) to stop this recurring a fifth time.
    # PRELUDE_VALUE_FAST WAS the one real PRELUDE_* constant in codegen.rs
    # not covered here (also not part of selfhost_runtime_text_parity's own
    # checked chunk list) -- added now: found genuinely stale (still
    # String(String)/List(Vec<Value>), years behind codegen.rs's real
    # Arc<String>/Arc<Vec<Value>>) via a manual codegen_prelude_chunk(
    # "__value_fast__") check while rebuilding patc1.exe, since
    # selfhost_pipeline.rs's tracked chunk list still doesn't include it.
    "value_fast": "PRELUDE_VALUE_FAST",
}

LINES_PER_SUBFN = 150

def extract_prelude(src, const_name):
    # const NAME: &'static str = r##"...."##;
    pat = re.compile(r'const\s+' + re.escape(const_name) + r'\s*:\s*&\'static str\s*=\s*r##"(.*?)"##\s*;', re.DOTALL)
    m = pat.search(src)
    if not m:
        raise SystemExit(f"could not find {const_name} in codegen.rs")
    return m.group(1)

def escape_patlang_string(line):
    out = []
    for ch in line:
        if ch == '\\':
            out.append('\\\\')
        elif ch == '"':
            out.append('\\"')
        elif ch == '\t':
            out.append('\\t')
        elif ch == '\r':
            out.append('\\r')
        else:
            out.append(ch)
    return ''.join(out)

def gen_chunk_functions(chunk_name, content):
    # content is exactly what must be reproduced (the raw string's body).
    # Splitting on '\n' preserves an eventual trailing '' if content ends with \n.
    lines = content.split('\n')
    trailing_newline = content.endswith('\n')
    if trailing_newline:
        lines = lines[:-1]  # drop the empty tail element from split

    groups = [lines[i:i+LINES_PER_SUBFN] for i in range(0, len(lines), LINES_PER_SUBFN)]
    if not groups:
        groups = [[]]

    out = io.StringIO()
    subfn_names = []
    for idx, group in enumerate(groups):
        fname = f"emit_runtime_rs_{chunk_name}_{idx}"
        subfn_names.append(fname)
        out.write(f"make a function called {fname} takes b returns done\n")
        n = len(group)
        for i, line in enumerate(group):
            esc = escape_patlang_string(line)
            is_last_overall = (idx == len(groups) - 1) and (i == n - 1)
            if is_last_overall and not trailing_newline:
                out.write(f'  sb_push(b, "{esc}")\n')
            else:
                out.write(f'  sb_push(b, "{esc}" + nl())\n')
        out.write("  return true\nend\n\n")

    out.write(f"make a function called emit_chunk_{chunk_name} returns s\n")
    out.write("  let b = sb_new()\n")
    for fname in subfn_names:
        out.write(f"  {fname}(b)\n")
    out.write("  return sb_str(b)\nend\n\n")
    return out.getvalue()

def main():
    codegen_src = open(CODEGEN, encoding='utf-8').read()
    runtime_src = open(RUNTIME_RS, encoding='utf-8').read()

    for chunk_name, const_name in CHUNKS.items():
        content = extract_prelude(codegen_src, const_name)
        new_block = gen_chunk_functions(chunk_name, content)

        # Remove ALL existing emit_runtime_rs_<chunk_name>_<n> sub-functions
        # and the emit_chunk_<chunk_name> function itself, wherever they are
        # in the file, then insert the fresh block at the position of the
        # FIRST removed occurrence (keeps chunks roughly where they were).
        subfn_pat = re.compile(
            r'make a function called emit_runtime_rs_' + re.escape(chunk_name) + r'_\d+ takes b returns done\n.*?\nend\n\n?',
            re.DOTALL
        )
        chunkfn_pat = re.compile(
            r'make a function called emit_chunk_' + re.escape(chunk_name) + r' returns s\n.*?\nend\n\n?',
            re.DOTALL
        )

        positions = [m.start() for m in subfn_pat.finditer(runtime_src)]
        cpos = [m.start() for m in chunkfn_pat.finditer(runtime_src)]
        all_positions = positions + cpos
        if not all_positions:
            print(f"WARNING: no existing functions found for chunk '{chunk_name}' -- will append at end")
            insert_at = None
        else:
            insert_at = min(all_positions)

        # Remove chunkfn first (as it may reference text after subfns), then subfns.
        runtime_src, n1 = chunkfn_pat.subn('', runtime_src)
        runtime_src, n2 = subfn_pat.subn('', runtime_src)
        print(f"{chunk_name}: removed {n1} emit_chunk fn(s), {n2} sub-fn(s)")

        if insert_at is None:
            runtime_src = runtime_src.rstrip('\n') + '\n\n' + new_block
        else:
            # positions were computed before removal; since removal only
            # deletes text at/after those same patterns, and we insert at
            # the smallest original offset, re-find a safe anchor: insert
            # right before the next surviving line that starts a chunk
            # boundary comment, or just before EOF-adjacent leftover ==
            # simplify: insert at the *current* location of the nearest
            # anchor by re-searching for a nearby marker instead of trusting
            # stale offsets after mutation.
            # Simplify further: just append after removal, ordering within
            # the file doesn't affect correctness (compilation of PatLang
            # doesn't require call-before-def; parity test doesn't care
            # about definition order).
            runtime_src = runtime_src.rstrip('\n') + '\n\n' + new_block

    with open(RUNTIME_RS, 'w', encoding='utf-8', newline='\n') as f:
        f.write(runtime_src)
    print("done")

if __name__ == '__main__':
    main()
