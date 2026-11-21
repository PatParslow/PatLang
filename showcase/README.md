# PatLang showcase

Small programs that each solve one recognisable problem by putting two or more of
PatLang's paradigms together. Each program's header says what the problem is and what
each paradigm contributes. Each has a counterpart in Python in `compare/`, written
the way a Python programmer would write it, with the standard library's own tools.

Every program here is run by the gates on the interpreter and as a native build for
Windows and for Linux. Its output must match `expected/NAME.txt` exactly (suites
`showcase` and `showcase_linux`, `self_hosting/tools/run_demos.patlang --dir showcase`).
The Python sketches are run too, and their output must match the program's, or
`compare/expected/NAME.txt` where the two differ by design (suite `showcase_compare`,
`self_hosting/tools/run_showcase_compare.patlang`).

## The paradigms

| Key | Paradigm | What a program uses |
|---|---|---|
| C | Design by contract | `require`, `ensure`, `assert`; each clause that holds recorded as a fact |
| L | Logic programming | `rule`, `solve`, stores (`logic_store_named`, `solve_in`) |
| G | Goals and planning | `action_add_numeric`, `plan_numeric`, `fluent_set`, `action_bind`, `activate` |
| E | Events | `when EVENT do`, `emit`, methods declared `raises EVENT` |
| O | Objects | classes, fields, methods, operators as methods |
| F | Functional | closures, `parallel_map` |
| N | Exact numbers | int, bigint and rational arithmetic, intervals, integers modulo n |
| K | Constant time | the compiler's `--constant-time` check |
| T | Threads and fibres | `thread_spawn`, `fiber_new`, `fiber_yield`, `fiber_resume`, `budgeted` |
| W | Worlds | `world_new`, `world_call`: facts, files, output and stopping of their own |
| S | Syntax definitions | a notation of the program's own, expanded before it runs |
| M | Messaging | signals (`signal_claim`, `signal_query`, `signal_announce`), the durable queue |
| B | Specifications | Gherkin features run by the program, declared schemas explored by `zs_explore` |

## The programs

| Program | Paradigms | What the Python sketch needed beyond the language |
|---|---|---|
| [p1_loan_schedule](p1_loan_schedule.patlang) | N C | `fractions` |
| [p2_access_rules](p2_access_rules.patlang) | L O | the rules as a function with its search written out, one question at a time |
| [p3_factory_plan](p3_factory_plan.patlang) | G N | a planner: a uniform-cost search with `heapq` |
| [p4_spreadsheet](p4_spreadsheet.patlang) | E O | an event bus; `fractions` |
| [p5_guaranteed_bounds](p5_guaranteed_bounds.patlang) | N C | an interval class over `fractions` |
| [p6_coroutine_lexer](p6_coroutine_lexer.patlang) | T S | nothing beyond generators and a dict; `fractions` for exact results |
| [p7_what_if](p7_what_if.patlang) | W L | the rules as functions; a copy of the data per proposal |
| [p8_exact_in_parallel](p8_exact_in_parallel.patlang) | T N | `multiprocessing`, since threads do not run Python code in parallel |
| [p9_watching_a_job](p9_watching_a_job.patlang) | M T | a TCP server, a registry file and a request queue (`socketserver`, `json`, `queue`) |
| [p10_key_exchange](p10_key_exchange.patlang) | K N | the X25519 ladder written out; no check of its timing |
| [p11_spec_in_its_own_words](p11_spec_in_its_own_words.patlang) | B S | a Gherkin step matcher; the notation read with `re` |
| [p12_agent_that_replans](p12_agent_that_replans.patlang) | G E | a planner: a uniform-cost search with `heapq` |
| [p13_contracts_as_data](p13_contracts_as_data.patlang) | C L | a contract decorator that records each clause |
| [p14_crash_safe_worker](p14_crash_safe_worker.patlang) | M W | `sqlite3` as the queue |
| [c1_budget_sheet](c1_budget_sheet.patlang) | O E N C | callbacks for the change event; `fractions` |
| [c2_game_agents](c2_game_agents.patlang) | G T E W | a planner (`heapq`); generators as the agents |
| [c3_build_system](c3_build_system.patlang) | L F M T | a process pool; a file of lines as the record |
| [c4_proven_calculator](c4_proven_calculator.patlang) | S N O C | an interval class; the notation read with `re` |
| [c5_specified_bank](c5_specified_bank.patlang) | B C N O | a state-space explorer for the schema; a Gherkin step matcher |

`p10_ct_exchange` and `p10_ct_leaky` are what the constant-time
check is run on: `v2.exe showcase/p10_ct_exchange.patlang --constant-time` reports no
value-dependent branch or access, and the same check refuses `p10_ct_leaky`, naming
the branch in `pin_matches`. The expected reports are in
`expected/*.constant_time.txt`, and the showcase suite checks them.

## Pages

Five of the programs also write a web page when given `--page PATH`, built as a
tree of element and text nodes with `self_hosting/lib/dom.patlang` and written out
by its one writer, which escapes every text node and attribute value as it writes.
Their text output is the same with or without it.

| Program | Its page |
|---|---|
| [p4_spreadsheet](p4_spreadsheet.patlang) | the sheet as a table, kept up to date by one more handler on `recalculated`; the cells know nothing of it |
| [p2_access_rules](p2_access_rules.patlang) | people against documents and actions, each cell holding its reason, one query per column |
| [p3_factory_plan](p3_factory_plan.patlang) | each plan as a row of steps, coloured by kind, with its cost |
| [p5_guaranteed_bounds](p5_guaranteed_bounds.patlang) | the bisection as an SVG drawing, each interval a bar titled with its exact bounds |
| [c3_build_system](c3_build_system.patlang) | the dependency graph in SVG, a column per wave, drawn from the builder's own facts |

The gates compare each page with `expected/NAME.html` on every engine. The
expected pages of P5 and C3 were computed from the drawings' rules by separate
Python scripts, `pages/p5_guaranteed_bounds_page.py` and
`pages/c3_build_system_page.py` (`py -3 -I pages/NAME_page.py >
expected/NAME.html`), so the programs' coordinates are checked against an
independent calculation.

## What the comparison shows

Each PatLang program says what it means in the terms of its problem. The access
policy is three rules, and any question about it is a query of those rules. A
factory's steps are actions, each with what it needs, what it changes and what it
costs, and the plan is asked for. A transfer's promise that the total is unchanged is
an `ensure` clause on the transfer. A failed job stops its own world. A reader
finds the policy, the plan's terms or the promise written down where they apply,
without first finding the machinery that carries them out.

The table's last column is that machinery, as the Python version needs it. Python
has excellent pieces for some of it (`fractions`, `sqlite3`, generators, `heapq`).
For the rest it relies on packages installed beside it (behave or pytest-bdd for
Gherkin, icontract for contracts, pyperplan for planning), or on a separate process
(for isolation that covers files and output), or on code the sketch writes for
itself: a planner, an interval class, an explorer, an event bus. Neither Python nor
its standard library has a way to check that code takes the same time whatever its
secret inputs.

## Speed

One program was timed, on the same machine, best of three runs (2026-11-20):

| p8_exact_in_parallel (H(3000) exactly, four ways, then in floats) | time |
|---|---|
| PatLang, interpreted | 2.90 s |
| PatLang, native build | 2.59 s |
| Python 3.13, `fractions` and a process pool | 0.31 s |

Python's big integers are written in C; PatLang's are written in PatLang, as lists
of base-10^9 limbs. Both reduce a sum of fractions the same way (Knuth, TAOCP
4.5.1), so the difference is the integer arithmetic underneath.
