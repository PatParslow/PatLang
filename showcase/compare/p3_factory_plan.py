"""The factory of showcase/p3_factory_plan.patlang, in Python.

Python has no planner of its own. The usual choices are a PDDL planner run as
a separate program (the domain and problem written out as PDDL text, the plan
read back) or a search written by hand. This is the second: a uniform-cost
search with heapq over states of facts and numbers, written before the
factory itself is described. The PatLang program states the actions and
asks; the search is the language's.

Prints each plan's cost and steps. Plans of equal cost can list their steps
in a different order from the PatLang program's, so the costs are what the two
are compared on.
"""
import heapq
import itertools

OPS = {"<": lambda a, b: a < b, "<=": lambda a, b: a <= b, ">": lambda a, b: a > b,
       ">=": lambda a, b: a >= b, "==": lambda a, b: a == b, "!=": lambda a, b: a != b}
EFFECTS = {"=": lambda a, b: b, "+=": lambda a, b: a + b, "-=": lambda a, b: a - b,
           "*=": lambda a, b: a * b}


class Action:
    def __init__(self, name, needs, num_needs, adds, dels, changes, cost):
        self.name, self.needs, self.num_needs = name, set(needs), num_needs
        self.adds, self.dels, self.changes, self.cost = set(adds), set(dels), changes, cost

    def applies(self, facts, nums):
        return self.needs <= facts and all(
            f in nums and OPS[op](nums[f], v) for f, op, v in self.num_needs)

    def apply(self, facts, nums):
        nums = dict(nums)
        for f, op, v in self.changes:
            nums[f] = EFFECTS[op](nums.get(f, 0), v)
        return (facts - self.dels) | self.adds, nums


def plan(actions, facts, nums, goal_facts, goal_nums):
    """The cheapest list of actions from the state to the goals, or None."""
    tie = itertools.count()
    start = (frozenset(facts), tuple(sorted(nums.items())))
    frontier = [(0, next(tie), start, [])]
    seen = set()
    while frontier:
        cost, _, state, steps = heapq.heappop(frontier)
        if state in seen:
            continue
        seen.add(state)
        f, n = set(state[0]), dict(state[1])
        if set(goal_facts) <= f and all(OPS[op](n.get(k, 0), v) for k, op, v in goal_nums):
            return cost, steps
        for a in actions:
            if a.applies(f, n):
                f2, n2 = a.apply(f, n)
                nxt = (frozenset(f2), tuple(sorted(n2.items())))
                if nxt not in seen:
                    heapq.heappush(frontier, (cost + a.cost, next(tie), nxt, steps + [a.name]))
    return None


def describe(result):
    cost, steps = result
    noun = "step" if len(steps) == 1 else "steps"
    return f"cost {cost}, {len(steps)} {noun}: [{', '.join(steps)}]"


nums = {"steel": 1, "blanks": 0, "power": 0, "widgets": 0}
actions = [
    Action("switch_on", [], [], ["press on"], [], [], 1),
    Action("buy_steel", [], [("steel", "<", 2)], [], [], [("steel", "+=", 1)], 4),
    Action("cut", [], [("steel", ">=", 1)], [], [], [("steel", "-=", 1), ("blanks", "+=", 1)], 1),
    Action("charge", [], [("power", "<", 4)], [], [], [("power", "+=", 2)], 1),
    Action("press", ["press on"], [("blanks", ">=", 1), ("power", ">=", 2)], [], [],
           [("blanks", "-=", 1), ("power", "-=", 2), ("widgets", "+=", 1)], 2),
    Action("buy_widget", [], [], [], [], [("widgets", "+=", 1)], 7),
]

print("== one widget ==")
print(describe(plan(actions, set(), nums, [], [("widgets", ">=", 1)])))

print("== three widgets ==")
print(describe(plan(actions, set(), nums, [], [("widgets", ">=", 3)])))

print("== three widgets, and the press switched off again ==")
actions.append(Action("switch_off", ["press on"], [], ["press off"], ["press on"], [], 1))
print(describe(plan(actions, set(), nums, ["press off"], [("widgets", ">=", 3)])))

print("== one widget, starting with no steel ==")
nums["steel"] = 0
print(describe(plan(actions, set(), nums, [], [("widgets", ">=", 1)])))
