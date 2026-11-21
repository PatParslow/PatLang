"""The calculator of showcase/p6_coroutine_lexer.patlang, in Python.

Python does this one well. A generator is a coroutine lexer, and next() pulls
one token at a time; an operator table is a dict literal. The PatLang program
writes its table in a notation of its own (a syntax definition) and keeps it
as facts it queries; in Python a dict is as short and needs nothing defined.
The difference that remains is the numbers: Python's / gives a float, so the
parser converts each number to a Fraction to keep 10 / 4 as 5/2.

Prints the same lines as the PatLang program.
"""
from fractions import Fraction
import operator

# symbol: (level, function)
OPERATORS = {
    "+": (1, operator.add),
    "-": (1, operator.sub),
    "*": (2, operator.mul),
    "/": (2, operator.truediv),
}


def lex(text):
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c.isdigit():
            v = 0
            while i < n and text[i].isdigit():
                v = v * 10 + int(text[i])
                i += 1
            yield ("num", Fraction(v))
        elif c == " ":
            i += 1
        elif c in "()":
            yield (c, "")
            i += 1
        else:
            yield ("op", c)
            i += 1
    while True:
        yield ("end", "")


class Parser:
    def __init__(self, text):
        self.lexer = lex(text)
        self.ahead = next(self.lexer)

    def peek(self):
        return self.ahead

    def take(self):
        tok, self.ahead = self.ahead, next(self.lexer)
        return tok


def primary(p):
    tok = p.take()
    if tok[0] == "num":
        return tok[1]
    if tok[0] == "(":
        v = expression(p, 1)
        assert p.take()[0] == ")"
        return v
    if tok == ("op", "-"):
        return -primary(p)
    raise SyntaxError(tok)


def expression(p, min_level):
    v = primary(p)
    while True:
        tok = p.peek()
        if tok[0] != "op" or OPERATORS[tok[1]][0] < min_level:
            return v
        level, f = OPERATORS[tok[1]]
        p.take()
        v = f(v, expression(p, level + 1))


def calculate(text):
    p = Parser(text)
    v = expression(p, 1)
    assert p.peek()[0] == "end"
    return v


def show(x):
    """A value as PatLang prints it: a whole fraction as an int."""
    return str(x.numerator) if x.denominator == 1 else str(x)


print("== the operators, as facts ==")
print(f"{len(OPERATORS)} operators declared")
print("== calculations ==")
for text in ["1 + 2 * 3", "(1 + 2) * 3", "10 / 4", "2 * (3 + 4) - 5 / 10", "-3 * -(2 + 1)", "1 / 3 + 1 / 6"]:
    print(f"{text} = {show(calculate(text))}")
