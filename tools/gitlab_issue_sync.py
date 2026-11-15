"""Bring csgitlab's patparslow/patlang issues up to date with GitHub's
PatParslow/PatLang: create the mirrors that are missing, match each mirror's
state and labels, and mirror each GitHub comment as a note (marked, so a rerun
adds none twice).

    py -3 tools/gitlab_issue_sync.py            say what would change
    py -3 tools/gitlab_issue_sync.py --apply    change it

Needs `gh` logged in to github.com and `glab` to csgitlab.reading.ac.uk. A
mirror is found by its first line, "Mirrored from GitHub issue [#N]"; GitLab's
numbers run one behind GitHub's, so new mirrors link `#N` to GitHub. Progress
goes to self_hosting/build/gitlab_issue_sync.progress."""
import json, os, re, subprocess, sys, urllib.parse

APPLY = "--apply" in sys.argv
GH = "PatParslow/PatLang"
HOST = "csgitlab.reading.ac.uk"
PROJ = urllib.parse.quote("patparslow/patlang", safe="")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(os.path.join(ROOT, "self_hosting", "build"), exist_ok=True)
PROG = open(os.path.join(ROOT, "self_hosting", "build", "gitlab_issue_sync.progress"), "a", encoding="utf-8")


def log(s):
    print(s, flush=True)
    PROG.write(s + "\n"); PROG.flush()


def run(cmd, data=None):
    r = subprocess.run(cmd, input=data, capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        raise RuntimeError(f"{cmd[:4]}: {r.stderr.strip()[:300]}")
    return r.stdout


def gh_json(path):
    return json.loads(run(["gh", "api", "--paginate", "--slurp", path]))


def gl(method, path, fields=None):
    cmd = ["glab", "api", "--hostname", HOST, "-X", method, path]
    if fields is None:
        return json.loads(run(cmd) or "null")
    # JSON body on stdin keeps long text intact
    cmd += ["-H", "Content-Type: application/json", "--input", "-"]
    return json.loads(run(cmd, json.dumps(fields)) or "null")


def gl_all(path):
    out, page = [], 1
    while True:
        sep = "&" if "?" in path else "?"
        got = gl("GET", f"{path}{sep}per_page=100&page={page}")
        out += got
        if len(got) < 100:
            return out
        page += 1


def link_refs(text):
    """Bare #N becomes a link to GitHub's issue N, outside fenced code."""
    parts = re.split(r"(```.*?```)", text or "", flags=re.S)
    for k in range(0, len(parts), 2):
        parts[k] = re.sub(r"(?<![\w/\[&])#(\d+)\b",
                          lambda m: f"[#{m.group(1)}](https://github.com/{GH}/issues/{m.group(1)})", parts[k])
    return "".join(parts)


MARK = re.compile(r"Mirrored from GitHub issue \[#(\d+)\]")
CMARK = re.compile(r"<!-- github-comment-(\d+) -->")

issues = [i for page in gh_json(f"repos/{GH}/issues?state=all&per_page=100") for i in page
          if "pull_request" not in i]
issues.sort(key=lambda i: i["number"])
log(f"github: {len(issues)} issues")
mirrors = {}
for m in gl_all(f"projects/{PROJ}/issues?state=all"):
    g = MARK.search(m.get("description") or "")
    if g:
        mirrors[int(g.group(1))] = m
log(f"gitlab: {len(mirrors)} mirrors")

created = closed = reopened = relabelled = notes = 0
for i in issues:
    n = i["number"]
    url = i["html_url"]
    labels = sorted(l["name"] for l in i["labels"])
    m = mirrors.get(n)
    if m is None:
        desc = (f"> Mirrored from GitHub issue [#{n}]({url}), originally opened by "
                f"**@{i['user']['login']}** on {i['created_at']}.\n\n---\n\n" + link_refs(i["body"]))
        log(f"create #{n}: {i['title'][:70]}")
        created += 1
        if APPLY:
            m = gl("POST", f"projects/{PROJ}/issues",
                   {"title": i["title"], "description": desc, "labels": ",".join(labels)})
        else:
            continue
    elif sorted(m["labels"]) != labels:
        log(f"labels #{n}: {m['labels']} -> {labels}")
        relabelled += 1
        if APPLY:
            m = gl("PUT", f"projects/{PROJ}/issues/{m['iid']}", {"labels": ",".join(labels)})
    want = "closed" if i["state"] == "closed" else "opened"
    if m["state"] != want:
        log(f"{'close' if want == 'closed' else 'reopen'} #{n} (gitlab {m['iid']})")
        if want == "closed": closed += 1
        else: reopened += 1
        if APPLY:
            gl("PUT", f"projects/{PROJ}/issues/{m['iid']}",
               {"state_event": "close" if want == "closed" else "reopen"})
    if i["comments"]:
        done = set()
        if "iid" in m:
            for note in gl_all(f"projects/{PROJ}/issues/{m['iid']}/notes"):
                c = CMARK.search(note.get("body") or "")
                if c: done.add(int(c.group(1)))
        for c in gh_json(f"repos/{GH}/issues/{n}/comments?per_page=100"):
            for cc in c:
                if cc["id"] in done: continue
                body = (f"<!-- github-comment-{cc['id']} -->\n> Comment by **@{cc['user']['login']}** on "
                        f"{cc['created_at']} ([GitHub]({cc['html_url']}))\n\n" + link_refs(cc["body"]))
                notes += 1
                if APPLY:
                    gl("POST", f"projects/{PROJ}/issues/{m['iid']}/notes", {"body": body})
log(f"{'done' if APPLY else 'dry run'}: create {created}, close {closed}, reopen {reopened}, "
    f"relabel {relabelled}, comments {notes}")
