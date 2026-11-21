"""The expected page of showcase/c3_build_system.patlang, from the layout
rules alone: waves by readiness, a column of 120 per wave, rows of 50 from 80,
edges as cubic curves that arc up 30 per wave skipped, then each wave's boxes
grouped, each box titled with its target's checksum."""
import sys

DEPENDS = [("app", "ui"), ("app", "core"), ("app", "net"), ("ui", "core"),
           ("net", "core"), ("core", "util"), ("tests", "app"), ("tests", "util")]
TARGETS = ["util", "core", "net", "ui", "app", "tests"]
SUMS = {"util": 1386, "core": 2942, "net": 2248, "ui": 1648, "app": 9125, "tests": 7150}

def deps(t):
    return [d for a, d in DEPENDS if a == t]

waves, built = [], []
while True:
    ready = [t for t in TARGETS if t not in built and all(d in built for d in deps(t))]
    if not ready:
        break
    waves.append(ready)
    built += ready

pos, wave_of = {}, {}
for k, w in enumerate(waves):
    for i, t in enumerate(w):
        pos[t] = (20 + 120 * k, 80 + 50 * i)
        wave_of[t] = k
width = 20 + 120 * len(waves)
height = 80 + 50 * max(len(w) for w in waves)
out = ['<!doctype html><html><head><meta charset="utf-8"><title>The build\'s dependencies</title></head><body>',
       "<h1>The build's dependencies</h1>",
       f'<svg width="{width}" height="{height}">']
for w in waves:
    for t in w:
        for d in deps(t):
            x1, y1 = pos[d][0] + 80, pos[d][1] + 15
            x2, y2 = pos[t][0], pos[t][1] + 15
            bend = -30 * (wave_of[t] - wave_of[d] - 1)
            out.append(f'<path d="M {x1} {y1} C {x1 + 40} {y1 + bend} {x2 - 40} {y2 + bend} {x2} {y2}" fill="none" stroke="#94a3b8"></path>')
for k, w in enumerate(waves):
    x = 20 + 120 * k
    out.append(f'<g id="wave-{k + 1}"><text x="{x + 40}" y="40" text-anchor="middle">wave {k + 1}</text>')
    for t in w:
        tx, ty = pos[t]
        out.append(f'<rect x="{tx}" y="{ty}" width="80" height="30" rx="4" fill="#e0e7ff" stroke="#6366f1"><title>{t}, checksum {SUMS[t]}</title></rect>')
        out.append(f'<text x="{tx + 40}" y="{ty + 20}" text-anchor="middle">{t}</text>')
    out.append("</g>")
out.append(f"</svg><p>{len(TARGETS)} targets in {len(waves)} waves</p></body></html>")
sys.stdout.write("".join(out) + "\n")
