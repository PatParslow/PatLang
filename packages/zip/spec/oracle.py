"""Test oracle for the zip package's Gherkin runner (tests only).

Python's zipfile is the reference. Entry names travel as hex of their UTF-8
bytes, so no console or command-line encoding touches them.

  zipmake ZIP SPECS [COMMENT]  write a zip; SPECS is comma-separated
                               HEXNAME=KIND:SIZE:METHOD (METHOD stored or
                               deflated; KIND as the deflate oracle's gen),
                               or HEXNAME=dir for a directory entry; an entry
                               with KIND "extra" gets an extra field
  zipextract ZIP OUTDIR        testzip() then, per entry, one line
                               "I HEXNAME METHOD SIZE" and OUTDIR/I.bin
"""
import importlib.util
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "deflate_oracle", os.path.join(HERE, "..", "..", "deflate", "spec", "oracle.py"))
deflate_oracle = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(deflate_oracle)


def zipmake(path, specs, comment):
    with zipfile.ZipFile(path, "w") as zf:
        for item in specs.split(","):
            if not item:
                continue
            hexname, rest = item.split("=", 1)
            name = bytes.fromhex(hexname).decode("utf-8")
            if rest == "dir":
                zf.mkdir(name.rstrip("/"))
                continue
            kind, size, method = rest.split(":")
            extra = kind == "extra"
            if extra:
                kind = "text"
            data = deflate_oracle.gen(kind, int(size))
            info = zipfile.ZipInfo(name, date_time=(2026, 11, 8, 12, 30, 0))
            info.compress_type = zipfile.ZIP_DEFLATED if method == "deflated" else zipfile.ZIP_STORED
            if extra:
                # a made-up header id 0xCAFE with four bytes of payload
                info.extra = bytes([0xFE, 0xCA, 4, 0, 1, 2, 3, 4])
            zf.writestr(info, data)
        if comment:
            zf.comment = comment.encode("ascii")
    print("ok")


def zipextract(path, outdir):
    os.makedirs(outdir, exist_ok=True)
    try:
        with zipfile.ZipFile(path) as zf:
            bad = zf.testzip()
            print("testzip ok" if bad is None else "testzip bad " + bad.encode("utf-8").hex())
            for i, info in enumerate(zf.infolist()):
                data = zf.read(info)
                with open(os.path.join(outdir, "%d.bin" % i), "wb") as f:
                    f.write(data)
                print("%d %s %d %d" % (i, info.filename.encode("utf-8").hex(), info.compress_type, len(data)))
    except (zipfile.BadZipFile, OSError, EOFError) as e:
        print("error " + str(e))


def main(argv):
    if argv[0] == "zipmake":
        zipmake(argv[1], argv[2], argv[3] if len(argv) > 3 else "")
    elif argv[0] == "zipextract":
        zipextract(argv[1], argv[2])
    else:
        raise SystemExit("unknown command " + argv[0])


if __name__ == "__main__":
    main(sys.argv[1:])
