"""The access rules of showcase/p2_access_rules.patlang, in Python.

The facts are sets of tuples, as a Python programmer would keep them, and the
three rules become one function that answers "who may do this, and why". The
function is the policy; in the PatLang program the policy is the three rules
and the search is the language's. Here the search order is written by hand,
and asking a different question (what may bob do? on which documents?) needs
another function, or this one generalised; the PatLang program asks those of
the same three rules by leaving a different argument unbound.

Prints the same lines as the PatLang program.
"""

ACTIONS = ["read", "edit", "share"]


class Org:
    def __init__(self):
        self.owns = []        # (person, doc)
        self.member = []      # (person, group)
        self.grant = []       # (group, action, doc)
        self.delegate = []    # (from, to, doc)

    def can(self, action, doc, who=None):
        """Every (who, how, via) that may do action to doc, or only those for
        one person, in the order the PatLang program's rules give them."""
        out = []
        for p, d in self.owns:
            if d == doc and action in ACTIONS and who in (None, p):
                out.append((p, "owner", p))
        for p, g in self.member:
            for g2, a, d in self.grant:
                if g2 == g and a == action and d == doc and who in (None, p):
                    out.append((p, "group", g))
        for frm, to, d in self.delegate:
            if d == doc and who in (None, to):
                # one answer for each reason the delegator has
                for _ in self.can(action, doc, frm):
                    out.append((to, "delegated", frm))
        return out


class Person:
    def __init__(self, org, name):
        self.org, self.name = org, name

    def join(self, group):
        self.org.member.append((self.name, group.name))
        return self

    def owns(self, doc):
        self.org.owns.append((self.name, doc.name))
        return self

    def delegate(self, to, doc):
        assert to.name != self.name
        self.org.delegate.append((self.name, to.name, doc.name))
        return self


class Group:
    def __init__(self, org, name):
        self.org, self.name = org, name

    def grant(self, action, doc):
        self.org.grant.append((self.name, action, doc.name))
        return self


class Document:
    def __init__(self, name):
        self.name = name


def who_may(org, action, doc):
    sols = org.can(action, doc.name)
    print(f"who may {action} the {doc.name}:")
    if not sols:
        print("  nobody")
    for who, how, via in sols:
        print(f"  {who}, as {how} ({via})")
    return len(sols)


def may(org, who, action, doc):
    sols = org.can(action, doc.name, who.name)
    if sols:
        print(f"{who.name} may {action} the {doc.name}, as {sols[0][1]}")
    else:
        print(f"{who.name} may not {action} the {doc.name}: no rule gives it")
    return bool(sols)


org = Org()
ada, bob, carol, dan = (Person(org, n) for n in ["ada", "bob", "carol", "dan"])
finance = Group(org, "finance")
budget, roadmap = Document("budget"), Document("roadmap")

ada.owns(budget)
bob.join(finance)
finance.grant("read", budget)
finance.grant("edit", budget)
dan.owns(roadmap)
dan.delegate(carol, roadmap)

print("== the policy, applied ==")
who_may(org, "edit", budget)
who_may(org, "share", roadmap)
may(org, carol, "edit", budget)

print("== carol joins finance ==")
carol.join(finance)
may(org, carol, "edit", budget)
who_may(org, "read", budget)

print("== ada delegates the budget to dan ==")
ada.delegate(dan, budget)
may(org, dan, "share", budget)
