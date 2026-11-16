"""Apply a set of text replacements to files, all or nothing.

    py -3 -I tools/edit_files.py SPEC [--check]

SPEC is a text file of blocks:

    @@@ file path/to/file.patlang
    @@@ old
    the lines to replace
    @@@ new
    the lines to put in their place
    @@@ end

`@@@ file PATH xN` replaces N occurrences (each must be there, and no more);
the default is exactly one. A file may have several blocks, applied in order.
An empty new part deletes the old lines. Blocks are whole lines: each line of
old and new ends with a newline. A replacement inside a line is a job for an
editor, not this tool. A content line cannot start with "@@@ ".

Every file keeps its line endings (CRLF or LF) and is read and written as
UTF-8. Every block is checked before any file is written: if one anchor is
missing or appears a different number of times, nothing is written and the
problems are listed. --check checks and writes nothing.

Exit status: 0 when every block applied (or would), 1 when any did not, 2 for
a malformed spec.
"""
import os
import sys

MARK = "@@@ "


class SpecError(Exception):
    pass


def parse_spec(text):
    """[(path, count, old, new)] from a spec's text."""
    blocks = []
    lines = text.replace("\r\n", "\n").split("\n")
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        if line.strip() == "":
            i += 1
            continue
        if not line.startswith(MARK + "file "):
            raise SpecError("line %d: expected '@@@ file PATH', got %r" % (i + 1, line))
        rest = line[len(MARK + "file "):].strip()
        count = 1
        parts = rest.rsplit(" ", 1)
        if len(parts) == 2 and parts[1].startswith("x") and parts[1][1:].isdigit():
            rest, count = parts[0].strip(), int(parts[1][1:])
        if not rest:
            raise SpecError("line %d: no path" % (i + 1))
        if count < 1:
            raise SpecError("line %d: a count of at least 1" % (i + 1))
        i += 1
        if i >= n or lines[i] != MARK + "old":
            raise SpecError("line %d: expected '@@@ old'" % (i + 1))
        i += 1
        old = []
        while i < n and lines[i] != MARK + "new":
            if lines[i].startswith(MARK):
                raise SpecError("line %d: expected '@@@ new', got %r" % (i + 1, lines[i]))
            old.append(lines[i])
            i += 1
        if i >= n:
            raise SpecError("block for %s has no '@@@ new'" % rest)
        i += 1
        new = []
        while i < n and lines[i] != MARK + "end":
            if lines[i].startswith(MARK):
                raise SpecError("line %d: expected '@@@ end', got %r" % (i + 1, lines[i]))
            new.append(lines[i])
            i += 1
        if i >= n:
            raise SpecError("block for %s has no '@@@ end'" % rest)
        i += 1
        if not old:
            raise SpecError("block for %s has no old lines" % rest)
        blocks.append((rest, count, "".join(l + "\n" for l in old), "".join(l + "\n" for l in new)))
    if not blocks:
        raise SpecError("no blocks")
    return blocks


def plan(blocks, root):
    """{path: (new text, crlf)} for the files, and a list of problems."""
    texts = {}
    problems = []
    for path, count, old, new in blocks:
        full = os.path.join(root, path)
        if path not in texts:
            try:
                with open(full, encoding="utf-8", newline="") as f:
                    raw = f.read()
            except OSError as e:
                problems.append("%s: cannot read (%s)" % (path, e.strerror))
                texts[path] = None
                continue
            texts[path] = [raw.replace("\r\n", "\n"), "\r\n" in raw]
        if texts[path] is None:
            continue
        body = texts[path][0]
        found = body.count(old)
        if found != count:
            first = old.split("\n", 1)[0]
            problems.append("%s: wanted %d of the block starting %r, found %d" % (path, count, first[:70], found))
            continue
        texts[path][0] = body.replace(old, new)
    out = {p: (t[0], t[1]) for p, t in texts.items() if t is not None}
    return out, problems


def main(argv):
    args = [a for a in argv if a != "--check"]
    check = "--check" in argv
    if len(args) != 1:
        print(__doc__.strip().split("\n\n")[0])
        print("usage: py -3 -I tools/edit_files.py SPEC [--check]")
        return 2
    try:
        with open(args[0], encoding="utf-8") as f:
            blocks = parse_spec(f.read())
    except SpecError as e:
        print("spec: %s" % e)
        return 2
    texts, problems = plan(blocks, os.getcwd())
    if problems:
        for p in problems:
            print("FAIL " + p)
        print("nothing written")
        return 1
    for path, (text, crlf) in texts.items():
        if not check:
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(text.replace("\n", "\r\n") if crlf else text)
        print("%s %s (%s)" % ("would edit" if check else "edited", path, "CRLF" if crlf else "LF"))
    print("%d blocks, %d files" % (len(blocks), len(texts)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
