"""The expected page of showcase/p5_guaranteed_bounds.patlang, computed
independently: bisect [1, 2] for the root of x*x - 2 with exact fractions
until the width is at most a millionth, and draw each interval as a bar."""
from fractions import Fraction
import math, sys

def iv(lo, hi):
    return f"[{lo},{hi}]"

def fx(x):
    return format(float(x), ".3f")

lo, hi = Fraction(1), Fraction(2)
seen = [(lo, hi)]
while hi - lo > Fraction(1, 1000000):
    mid = (lo + hi) / 2
    if mid * mid > 2:
        hi = mid
    else:
        lo = mid
    seen.append((lo, hi))
steps = len(seen) - 1
height = len(seen) * 10
out = ['<!doctype html><html><head><meta charset="utf-8"><title>Squeezing the square root of 2</title></head><body>',
       '<h1>Squeezing the square root of 2</h1>',
       f'<svg width="400" height="{height}">']
for k, (a, b) in enumerate(seen):
    out.append(f'<rect x="{fx((a - 1) * 400)}" y="{k * 10}" width="{fx((b - a) * 400)}" height="8" fill="#60a5fa"><title>{iv(a, b)}</title></rect>')
root2 = math.sqrt(2.0)
x = format((root2 - 1) * 400, ".3f")
out.append(f'<line x1="{x}" y1="0" x2="{x}" y2="{height}" stroke="#dc2626"></line>')
out.append('</svg>')
out.append(f'<p>after {steps} steps the root lies in {iv(*seen[-1])}</p></body></html>')
sys.stdout.write("".join(out) + "\n")
