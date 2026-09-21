"""Independent reference for self_hosting/tools/zs_explore_bench.patlang.

Counts the reachable states and enabled transitions of the LibraryLoans schema
(T titles, M members, loan limit 3, loanCount keeping a zero-valued key after a
member returns everything) by a plain breadth-first search over Python
frozensets. It shares no code, and no representation, with the PatLang
explorer, so agreement between the two is evidence about the explorer and not
about a shared bug.

Run:  py -3.11 self_hosting/tools/zs_explore_reference.py
"""

import sys
from collections import deque

LIMIT = 3


def explore(titles: int, members: int):
    # state = (frozenset of (title, member) loans, frozenset of (member, count) keys)
    start = (frozenset(), frozenset())
    seen = {start}
    queue = deque([start])
    transitions = 0
    while queue:
        loans, counts = queue.popleft()
        held = {t for t, _ in loans}
        count_of = dict(counts)
        for t in range(titles):
            for m in range(members):
                # BorrowBook(t, m): title free, member under the limit
                if t not in held and count_of.get(m, 0) < LIMIT:
                    transitions += 1
                    nc = dict(count_of)
                    nc[m] = nc.get(m, 0) + 1
                    nxt = (loans | {(t, m)}, frozenset(nc.items()))
                    if nxt not in seen:
                        seen.add(nxt)
                        queue.append(nxt)
            # ReturnBook(t): title is out
            if t in held:
                transitions += 1
                owner = next(m for tt, m in loans if tt == t)
                nc = dict(count_of)
                nc[owner] -= 1
                nxt = (frozenset(x for x in loans if x[0] != t), frozenset(nc.items()))
                if nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)
    return len(seen), transitions


if __name__ == "__main__":
    sizes = [(3, 2), (4, 2), (5, 2), (6, 2), (7, 2)]
    if len(sys.argv) == 3:
        sizes = [(int(sys.argv[1]), int(sys.argv[2]))]
    for t, m in sizes:
        s, tr = explore(t, m)
        print(f"T={t} M={m} states={s} transitions={tr}")
