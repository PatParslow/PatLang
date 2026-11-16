"""Tests for tools/edit_files.py. Run: py -3 -I tools/test_edit_files.py"""
import os
import subprocess
import sys
import tempfile
import unittest

TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "edit_files.py")


def run(cwd, spec_text, *flags):
    spec = os.path.join(cwd, "spec.txt")
    with open(spec, "w", encoding="utf-8", newline="\n") as f:
        f.write(spec_text)
    r = subprocess.run([sys.executable, "-I", TOOL, spec] + list(flags), cwd=cwd,
                       capture_output=True, text=True, encoding="utf-8")
    return r.returncode, r.stdout


def write(cwd, name, text):
    with open(os.path.join(cwd, name), "w", encoding="utf-8", newline="") as f:
        f.write(text)


def read(cwd, name):
    with open(os.path.join(cwd, name), encoding="utf-8", newline="") as f:
        return f.read()


class EditFiles(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_crlf_file_keeps_crlf(self):
        write(self.d, "a.txt", "one\r\ntwo\r\nthree\r\n")
        rc, out = run(self.d, "@@@ file a.txt\n@@@ old\ntwo\n@@@ new\nTWO\n2\n@@@ end\n")
        self.assertEqual(rc, 0, out)
        self.assertEqual(read(self.d, "a.txt"), "one\r\nTWO\r\n2\r\nthree\r\n")

    def test_lf_file_keeps_lf(self):
        write(self.d, "a.txt", "one\ntwo\n")
        rc, out = run(self.d, "@@@ file a.txt\n@@@ old\none\n@@@ new\nONE\n@@@ end\n")
        self.assertEqual(rc, 0, out)
        self.assertEqual(read(self.d, "a.txt"), "ONE\ntwo\n")

    def test_missing_anchor_writes_nothing_in_any_file(self):
        write(self.d, "a.txt", "one\n")
        write(self.d, "b.txt", "two\n")
        spec = ("@@@ file a.txt\n@@@ old\none\n@@@ new\nONE\n@@@ end\n"
                "@@@ file b.txt\n@@@ old\nnot there\n@@@ new\nx\n@@@ end\n")
        rc, out = run(self.d, spec)
        self.assertEqual(rc, 1)
        self.assertIn("nothing written", out)
        self.assertEqual(read(self.d, "a.txt"), "one\n")
        self.assertEqual(read(self.d, "b.txt"), "two\n")

    def test_an_anchor_found_twice_is_refused(self):
        write(self.d, "a.txt", "x\nx\n")
        rc, out = run(self.d, "@@@ file a.txt\n@@@ old\nx\n@@@ new\ny\n@@@ end\n")
        self.assertEqual(rc, 1)
        self.assertIn("found 2", out)
        self.assertEqual(read(self.d, "a.txt"), "x\nx\n")

    def test_a_count_replaces_that_many(self):
        write(self.d, "a.txt", "x\nx\nz\n")
        rc, out = run(self.d, "@@@ file a.txt x2\n@@@ old\nx\n@@@ new\ny\n@@@ end\n")
        self.assertEqual(rc, 0, out)
        self.assertEqual(read(self.d, "a.txt"), "y\ny\nz\n")

    def test_blocks_on_one_file_apply_in_order(self):
        write(self.d, "a.txt", "a\n")
        spec = ("@@@ file a.txt\n@@@ old\na\n@@@ new\nb\n@@@ end\n"
                "@@@ file a.txt\n@@@ old\nb\n@@@ new\nc\n@@@ end\n")
        rc, out = run(self.d, spec)
        self.assertEqual(rc, 0, out)
        self.assertEqual(read(self.d, "a.txt"), "c\n")

    def test_an_empty_new_part_deletes(self):
        write(self.d, "a.txt", "keep\ndrop\nkeep too\n")
        rc, out = run(self.d, "@@@ file a.txt\n@@@ old\ndrop\n@@@ new\n@@@ end\n")
        self.assertEqual(rc, 0, out)
        self.assertEqual(read(self.d, "a.txt"), "keep\nkeep too\n")

    def test_quotes_and_backslashes_are_plain_text(self):
        write(self.d, "a.txt", 'let s = "a\\"b" + get(x, "k")\n')
        spec = '@@@ file a.txt\n@@@ old\nlet s = "a\\"b" + get(x, "k")\n@@@ new\nlet s = "\\\\"\n@@@ end\n'
        rc, out = run(self.d, spec)
        self.assertEqual(rc, 0, out)
        self.assertEqual(read(self.d, "a.txt"), 'let s = "\\\\"\n')

    def test_check_writes_nothing(self):
        write(self.d, "a.txt", "one\n")
        rc, out = run(self.d, "@@@ file a.txt\n@@@ old\none\n@@@ new\nONE\n@@@ end\n", "--check")
        self.assertEqual(rc, 0, out)
        self.assertIn("would edit", out)
        self.assertEqual(read(self.d, "a.txt"), "one\n")

    def test_a_malformed_spec_exits_2(self):
        write(self.d, "a.txt", "one\n")
        rc, out = run(self.d, "@@@ file a.txt\n@@@ old\none\n@@@ end\n")
        self.assertEqual(rc, 2)
        self.assertEqual(read(self.d, "a.txt"), "one\n")

    def test_a_missing_file_is_reported(self):
        rc, out = run(self.d, "@@@ file nope.txt\n@@@ old\nx\n@@@ new\ny\n@@@ end\n")
        self.assertEqual(rc, 1)
        self.assertIn("cannot read", out)

    def test_utf8_text_round_trips(self):
        write(self.d, "a.txt", "café — ok\r\n")
        rc, out = run(self.d, "@@@ file a.txt\n@@@ old\ncafé — ok\n@@@ new\ncafé – fine\n@@@ end\n")
        self.assertEqual(rc, 0, out)
        self.assertEqual(read(self.d, "a.txt"), "café – fine\r\n")


if __name__ == "__main__":
    r = unittest.main(exit=False, verbosity=1).result
    ok = r.wasSuccessful()
    print("ALL TESTS PASSED" if ok else "TESTS FAILED")
    sys.exit(0 if ok else 1)
