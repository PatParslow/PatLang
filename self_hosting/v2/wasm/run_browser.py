"""Runs a v2 WASM module in headless Chrome, with the host in this folder.

    py -3 self_hosting/v2/wasm/run_browser.py [--files DIR]... PROGRAM.wasm [ARGS...]

It serves this folder and the program from 127.0.0.1 with the headers that
make the page cross-origin isolated (so it has SharedArrayBuffer), opens the
page in a new headless Chrome profile, and waits for the page to post its
result. The program's output goes to stdout and its exit code is this
script's. CHROME names the browser when it is not in the usual place. Each
--files DIR gives the program every file under DIR to read, at its path
relative to the current directory: the page fetches them as one bundle.
"""
import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
TYPES = {".html": "text/html", ".mjs": "text/javascript", ".js": "text/javascript", ".wasm": "application/wasm"}
CHROMES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
]


def bundle(dirs):
    """The files under each directory, as the page fetches them: JSON mapping
    each path, relative to the current directory with "/" between its parts,
    to its bytes in base64."""
    files = {}
    for d in dirs:
        for root, _subdirs, names in os.walk(d):
            for name in names:
                full = os.path.join(root, name)
                with open(full, "rb") as f:
                    files[os.path.relpath(full).replace("\\", "/")] = base64.b64encode(f.read()).decode()
    return json.dumps(files).encode()


def serve(program, files):
    result = {}
    got = threading.Event()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def send(self, code, body, ctype):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = self.path.split("?")[0].lstrip("/") or "index.html"
            if path == "files.json" and files is not None:
                return self.send(200, files, "application/json")
            if path == "program.wasm":
                full = program
            elif "/" not in path and "\\" not in path and os.path.isfile(os.path.join(HERE, path)):
                full = os.path.join(HERE, path)
            else:
                return self.send(404, b"not found", "text/plain")
            with open(full, "rb") as f:
                self.send(200, f.read(), TYPES.get(os.path.splitext(full)[1], "application/octet-stream"))

        def do_POST(self):
            if self.path != "/result":
                return self.send(404, b"not found", "text/plain")
            n = int(self.headers.get("Content-Length", "0"))
            result.update(json.loads(self.rfile.read(n)))
            self.send(200, b"ok", "text/plain")
            got.set()

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, result, got


def main(argv):
    dirs = []
    while len(argv) > 2 and argv[1] == "--files":
        dirs.append(argv[2])
        argv = argv[:1] + argv[3:]
    if len(argv) < 2:
        print("usage: run_browser.py [--files DIR]... PROGRAM.wasm [ARGS...]")
        return 2
    chrome = os.environ.get("CHROME") or next((c for c in CHROMES if os.path.isfile(c)), None)
    if not chrome:
        print("run_browser: no Chrome found; set CHROME")
        return 2
    server, result, got = serve(os.path.abspath(argv[1]), bundle(dirs) if dirs else None)
    query = "report&args=" + json.dumps(argv[2:]).replace(" ", "%20")
    if dirs:
        query += "&files=files.json"
    url = "http://127.0.0.1:%d/index.html?%s" % (server.server_address[1], query)
    profile = tempfile.mkdtemp(prefix="patlang_chrome_")
    proc = subprocess.Popen([chrome, "--headless=new", "--no-first-run", "--no-default-browser-check",
                             "--disable-extensions", "--user-data-dir=" + profile, url],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        # the page posts once the program has finished; a browser that quits
        # first has failed
        while not got.wait(1):
            if proc.poll() is not None:
                print("run_browser: the browser quit before the page reported")
                return 1
    finally:
        proc.kill()
        proc.wait()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)
    if "error" in result:
        print("run_browser: the page failed: " + result["error"])
        return 1
    sys.stdout.buffer.write(base64.b64decode(result["out"]))
    sys.stdout.flush()
    return result["code"]


if __name__ == "__main__":
    sys.exit(main(sys.argv))
