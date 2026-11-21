"""The two coin-seeking agents of showcase/c2_game_agents.patlang, in Python.

Python's generators make good agents: the game sends each one the state and
it yields its next move, as the PatLang fibres do. Python has no planner in
its standard library, so the sketch writes a cheapest-first search over
(position, has a coin); the PatLang agents describe their moves as actions
with conditions, effects and costs and ask plan_numeric. Planning in a world
of its own needs no counterpart here, because the search keeps its state in
local variables; the PatLang planner's actions and fluents are stores, and
the world keeps one agent's out of the other's.

Prints the same lines as the PatLang program.
"""
import heapq
from itertools import count


def plan_for(pos, coins):
    """The cheapest moves from pos to holding a coin: each move costs 1."""
    tie = count()
    frontier = [(0, next(tie), pos, False, [])]
    seen = set()
    while frontier:
        cost, _, p, has, steps = heapq.heappop(frontier)
        if has:
            return steps
        if (p, has) in seen:
            continue
        seen.add((p, has))
        moves = []
        if p < 6:
            moves.append(("right", p + 1, False))
        if p > 0:
            moves.append(("left", p - 1, False))
        for c in coins:
            if p == c:
                moves.append((f"take_at_{c}", p, True))
        for name, np, nhas in moves:
            heapq.heappush(frontier, (cost + 1, next(tie), np, nhas, steps + [name]))
    return []


class Agent:
    def __init__(self, name, pos):
        self.name, self.pos, self.has_coin, self.stale, self.plan = name, pos, False, True, []


def agent_loop(agent, game):
    while not agent.has_coin:
        if agent.stale:
            agent.plan = plan_for(agent.pos, game["coins"])
            agent.stale = False
            game["log"].append(f"{agent.name} plans: [{', '.join(agent.plan)}]")
        move = agent.plan.pop(0)
        yield move
    while True:
        yield "done"


game = {"coins": [2, 5], "log": []}
ann, bo = Agent("ann", 0), Agent("bo", 3)
agents = [ann, bo]


def coin_taken(name, at):
    game["log"].append(f"{name} takes the coin at {at}")
    for other in agents:
        if other.name != name and not other.has_coin:
            other.stale = True


def apply_move(agent, move):
    if move == "right":
        agent.pos += 1
    elif move == "left":
        agent.pos -= 1
    elif move != "done":
        if agent.pos in game["coins"]:
            game["coins"] = [c for c in game["coins"] if c != agent.pos]
            agent.has_coin = True
            coin_taken(agent.name, agent.pos)
        else:
            agent.stale = True


loops = [agent_loop(a, game) for a in agents]
turn = 0
while (not ann.has_coin or not bo.has_coin) and turn < 20:
    for agent, loop in zip(agents, loops):
        if not agent.has_coin:
            move = next(loop)
            apply_move(agent, move)
            game["log"].append(f"turn {turn + 1}: {agent.name} {move}, now on {agent.pos}")
    turn += 1

print("\n".join(game["log"]))
print(f"ann has a coin: {'true' if ann.has_coin else 'false'}, bo has a coin: {'true' if bo.has_coin else 'false'}")
