"""Extracts RFC 8448's section 3 trace (a simple 1-RTT handshake) into
spec/data/rfc8448_simple.txt, one value a line:

    WHO|STEP|LABEL|HEX

e.g. "client|send handshake record|complete record|17030300...". WHO is client
or server, STEP the text after "{who}" up to its colon, LABEL the text before
"(N octets)"; values given as "(empty)" are left out. The RFC's page breaks
(footer and header lines) are skipped.

    py -3 -I packages/tls/spec/rfc8448_extract.py RFC8448.txt
"""
import os
import re
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "rfc8448_simple.txt")
STEP = re.compile(r"^   \{(client|server)\}  (.*?):?\s*$")
FIELD = re.compile(r"^      ([A-Za-z][A-Za-z ]*?) \((\d+) octets\):\s+(.*)$")
HEXLINE = re.compile(r"^\s+([0-9a-f]{2}( [0-9a-f]{2})*)\s*$")


def main(path):
    lines = open(path, encoding="ascii", errors="replace").read().split("\n")
    start = next(i for i, l in enumerate(lines) if l.startswith("3.  Simple 1-RTT Handshake"))
    end = next(i for i, l in enumerate(lines) if l.startswith("4.  Resumed 0-RTT Handshake"))
    out = []
    who, step, label, count, hexes = None, None, None, 0, []

    def flush():
        if label is not None and hexes:
            value = "".join(hexes).replace(" ", "")
            if len(value) != 2 * count:
                raise SystemExit("%s %s %s: %d octets read, %d said" % (who, step, label, len(value) // 2, count))
            out.append("|".join([who, step, label, value]))

    for line in lines[start:end]:
        if line.startswith("Thomson ") or line.startswith("RFC 8448 "):
            continue
        m = STEP.match(line)
        if m:
            flush()
            who, step, label, hexes = m.group(1), m.group(2).strip(), None, []
            continue
        m = FIELD.match(line)
        if m:
            flush()
            label, count, rest = m.group(1).strip(), int(m.group(2)), m.group(3).strip()
            hexes = [] if rest == "(empty)" or not re.match(r"^[0-9a-f]{2}", rest) else [rest]
            continue
        m = HEXLINE.match(line)
        if m and label is not None:
            hexes.append(m.group(1))
    flush()
    with open(OUT, "w", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print(len(out), "values to", OUT)


if __name__ == "__main__":
    main(sys.argv[1])
