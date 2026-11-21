"""The replanning robot of showcase/p12_agent_that_replans.patlang, in Python.

Python has no planner in its standard library, so the sketch writes the one
it needs: a uniform-cost search with heapq over states held as tuples, each
action a name, a test, an effect and a cost. That is the part the PatLang
program gets from plan_numeric. The event becomes a callback the walk action
calls. A Python project could use a planning package (pyperplan, for STRIPS
problems written in PDDL) instead of writing the search.

Prints the same lines as the PatLang program.
"""
import heapq
from itertools import count

PLACES = {0: "dock", 1: "hall", 2: "office"}

# name: (needs(state), effect(state) -> state, cost); a state is a dict of numbers
ACTIONS = {
    "pick_up": (lambda s: s["pos"] == 0 and s["carrying"] == 0, lambda s: {**s, "carrying": 1}, 1),
    "walk_to_hall": (lambda s: s["pos"] == 0, lambda s: {**s, "pos": 1}, 2),
    "through_door": (lambda s: s["pos"] == 1 and s["door_open"] == 1, lambda s: {**s, "pos": 2}, 1),
    "take_lift": (lambda s: s["pos"] == 1, lambda s: {**s, "pos": 2}, 6),
    "hand_over": (lambda s: s["pos"] == 2 and s["carrying"] == 1, lambda s: {**s, "carrying": 0, "delivered": 1}, 1),
}


def plan(start, goal):
    """The cheapest sequence of action names from start to a state meeting goal."""
    tie = count()
    frontier = [(0, next(tie), start, [])]
    seen = set()
    while frontier:
        cost, _, state, steps = heapq.heappop(frontier)
        key = tuple(sorted(state.items()))
        if key in seen:
            continue
        seen.add(key)
        if goal(state):
            return steps
        for name, (needs, effect, c) in ACTIONS.items():
            if needs(state):
                heapq.heappush(frontier, (cost + c, next(tie), effect(state), steps + [name]))
    return None


class Robot:
    def __init__(self):
        self.pos, self.carrying, self.delivered, self.door_open = 0, 0, 0, 1
        self.stale, self.log = False, []

    def state(self):
        return {"pos": self.pos, "carrying": self.carrying, "delivered": self.delivered, "door_open": self.door_open}


robot = Robot()


def door_locked(what):
    robot.door_open, robot.stale = 0, True
    robot.log.append(f"event: the {what} is locked")


def walk_to_hall():
    robot.pos = 1
    door_locked("office door")  # the building, not the robot, decides this


def hand_over():
    robot.carrying, robot.delivered = 0, 1


DO = {
    "pick_up": lambda: setattr(robot, "carrying", 1),
    "walk_to_hall": walk_to_hall,
    "through_door": lambda: setattr(robot, "pos", 2),
    "take_lift": lambda: setattr(robot, "pos", 2),
    "hand_over": hand_over,
}


def replan(r):
    r.stale = False
    steps = plan(r.state(), lambda s: s["delivered"] == 1)
    r.log.append(f"plan from the {PLACES[r.pos]}: [{', '.join(steps)}]")
    return steps


steps = replan(robot)
i = 0
while robot.delivered == 0:
    if robot.stale:
        steps, i = replan(robot), 0
    DO[steps[i]]()
    robot.log.append(f"did {steps[i]}, now in the {PLACES[robot.pos]}")
    i += 1

print("\n".join(robot.log))
print("delivered: " + ("true" if robot.delivered == 1 else "false"))
