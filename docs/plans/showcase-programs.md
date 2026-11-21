# Showcase programs

A set of programs that show what PatLang does well: paradigms used together in one
program, starting with pairs, and programs that would take noticeably more work in
another language. The seven programs in `demos/` cover each group of paradigms once
and all of them together in one (`07_bakery_all_paradigms`). These programs go
further: each one is built around a specific combination of paradigms.

Nothing here is built yet. This is the plan for building them.

## 1. What a showcase program must be

- **Small and real.** 100 to 300 lines solving a problem someone would recognise (a
  ledger, a build, a game agent), not a feature tour. The combination of paradigms
  is what makes the solution short, and the program's header says how.
- **Checked like the demos.** It runs interpreted and compiled, and its output is
  compared with `expected/NAME.txt` by a gates suite. Where it uses nothing a
  browser lacks, it also runs as WASM under Node. Unless it uses Windows-only
  libraries, it also runs on Linux under WSL. Output must not depend on timing,
  ports or paths.
- **A claim we can stand behind.** Each program has a short write-up of what would
  be harder elsewhere. Every such claim is checked before it is published: write
  the comparison sketch (Python, Rust, Prolog or whichever applies) far enough to
  see the difference, and state it modestly. "Python has `fractions`, but it is
  opt-in and floats are the default" is fair; "impossible in Python" never is.
- **Using only what works today.** A program that runs into a bug files the bug and
  waits, or picks another design. It never works around the bug silently. Known gaps
  now: list allocation cost (#273), image loading (#274), no outbound HTTP or TLS
  (#272).

## 2. The paradigms, as PatLang has them

| Key | Paradigm | What a program uses |
|---|---|---|
| C | Design by contract | `require`, `ensure`, `assert`; contracts as facts (`rt_contract_facts`) |
| L | Logic programming | `fact`, `rule`, stores (`logic_store_new`, `rule_add_to`, `solve_in`) |
| G | Goals and planning | `action_add`, `plan`, numeric fluents (`fluent_set`, `plan_numeric`), `goal`/`pursue` |
| E | Events | `when EVENT do`, `emit`, operator methods and the events they raise |
| O | Objects | classes, inheritance, traits, methods |
| F | Functional | closures, `parallel_map` over closures, pattern matching |
| N | Exact numbers | the tower: int to bigint to rational, plus intervals, modular integers and complex |
| K | Constant time | `--constant-time`, curve25519, `cpu_cycles` to measure it |
| T | Threads and fibres | `thread_spawn`, `fiber_new`/`fiber_yield`/`fiber_resume`, `budgeted(ms)` |
| W | Worlds | isolated state, output and stopping per world |
| S | Syntax definitions | the program's own syntax (`syntax_definitions.feature`) |
| M | Messaging | signals (`signal_claim`, `signal_query`), the durable queue |
| B | Specifications | Gherkin (`lib/gherkin.patlang`), declared Z-style schemas (`zs_*`) |

The toolchain is also a selling point. One source runs on the interpreter and as a
native build for Windows or Linux, and the same compiler builds it as WASM. The
gates check that each prints the same.

## 3. Phase 1: pairs

One program per pair. Each pair is one the problem actually needs, not just two
paradigms placed side by side. Listed roughly in the order to build them, the
simplest and most persuasive first.

| # | Pair | Program | What the pair gives |
|---|---|---|---|
| P1 | N + C | **A loan and its schedule.** Amortisation in exact rationals, with `ensure` clauses that the payments sum to the principal plus interest, to the penny. | The contract holds exactly, with no tolerance. A float version is printed beside it to show the drift. |
| P2 | L + O | **Who may do what.** Objects (users, groups, documents) put facts in a store, and rules derive access, delegation and the reason for each answer. | The policy is three rules, not a tree of `if`s, and `solve_in` gives the reason for each answer. |
| P3 | G + N | **A small factory.** Planning with numeric fluents: machines, stock levels and power, with a goal of "50 widgets"; the planner finds the order and the counts. | Planning with numbers in the language itself, with no PDDL tool or solver to wire in. |
| P4 | E + O | **A spreadsheet.** Cells are objects, a change emits an event, and dependants recalculate; a cycle is caught by the events' own no-reentry rule. | Recalculation is how events already behave, so the program has no observer framework. |
| P5 | N + C (intervals) | **Guaranteed bounds.** A projectile or orbit step in intervals, with `ensure` that the true answer is inside; tighter steps narrow it. | Error bounds that are proven, not estimated. |
| P6 | T + S | **A coroutine lexer.** A small language defined with syntax definitions, read by a fibre that yields a token at a time to a parser. | A streaming parser with no callbacks and no hand-written state machine. |
| P7 | W + L | **What-if.** Hypothetical reasoning: try each candidate change to a rule base in its own world, keep the ones whose queries still hold, and discard the rest untouched. | Rollback for free: a world cannot touch the program's state. |
| P8 | T + N | **Exact in parallel.** Bernoulli numbers or a harmonic sum in rationals, through `parallel_map`, with the same digits for any number of workers. | Parallel and exact at once, and deterministic. |
| P9 | M + T | **Watching a long job.** A budgeted job, and a second program that finds it by `signal_announce` and asks it for its status while it works. | Live monitoring from outside, a few lines on each side. |
| P10 | K + N | **A key exchange.** X25519 between two parties in modular integers, built `--constant-time`, with `cpu_cycles` showing no dependence on the key. | Constant-time code checked by the compiler, not by careful hand-writing. |
| P11 | B + S | **A spec in its own words.** A Gherkin feature whose steps use a domain syntax defined in the program. | The spec and its language live in one file. |
| P12 | G + E | **An agent that replans.** A GOAP agent carries out its plan; an event (a door locks, stock runs out) invalidates a step, and it plans again from where it is. | Reacting and planning in one loop, with no game engine. |
| P13 | C + L | **Contracts you can query.** A program asks which of its own functions have been checked and how often, through the contract facts. | Contracts treated as data about the program. |
| P14 | M + W | **A crash-safe worker.** Jobs come off the durable queue, each runs in its own world, a failing job stops only its world, and only completed jobs are acked. | Isolation and durability without processes or a broker. |

Phase 1 is done when each pair has its program, expected output and write-up, all in
the gates. The pairs not listed (there are 78 possible) are left out on purpose:
for those, the problem doesn't need both paradigms.

## 4. Phase 2: three or more

Each builds on Phase 1 programs, reusing their parts where it can.

- **A self-checking spreadsheet** (O + E + N + C): P4 with rational cells and
  contracts that totals balance.
- **A game with thinking agents** (G + T + E + W): each agent a fibre, planning
  (P12); before acting it tries its plan in a world to look ahead.
- **A build system in a page** (L + F + M + T): rules give the dependency order,
  `parallel_map` builds what is ready, the queue makes it resumable after a crash,
  and signals answer "what are you doing" (the gates tool does this at scale; this
  is the readable version).
- **A calculator with proven answers** (S + N + C): a syntax for expressions,
  evaluated in intervals and exactly, with contracts linking the two.
- **A specified bank** (B + C + N + O): a declared schema for accounts, checked by
  the program's contracts, with exact money and scenarios that exercise it.

## 5. Phase 3: the toolchain itself

- **One source, every target.** A single program (a Phase 2 one) built for
  Windows, for Linux, and as WASM in the browser, plus the interpreter, with the
  four outputs shown to be the same. This is a page in `docs/guides/`, not a new
  program.
- **The compiler compiles itself.** A short guide: the compiler unit's
  generations, byte-identical, on Windows and on Linux, from the bootstrap IR with
  no other compiler.

## 5a. Phase 4: a presentation layer, on the in-program DOM

Some of the programs gain a page: the same program, with its results built
as a document tree and written out as HTML. This needs the in-program DOM of
GitHub #270 first. Today `self_hosting/lib/html.patlang` assembles markup as
text, and has an escape function, a page template and an HTTP response.

- **The DOM library first** (#270): elements, attributes and text nodes as
  objects; create, append, set and read attributes, and query by tag, id and
  class; one writer that turns a tree into HTML and escapes every text node and
  attribute value as it writes, so a value in a text node can never become
  markup. Its selftest includes a round trip through `lib/html_scan.patlang`,
  and checks that a hostile text node comes out escaped.
- **Then the pages**, each a small addition to an existing program, chosen
  where the DOM does something the text output cannot:
  - **P4, the spreadsheet:** the sheet as a table. The `changed` handler
    updates the cells' nodes, so the page is one more handler, and the cells
    still know nothing of it.
  - **P2, the access rules:** a matrix of people against documents and
    actions, each cell holding its reason, built from one query per column.
  - **P3, the factory:** each plan as a row of steps, coloured by kind, with its
    cost.
  - **P5, the bounds:** the bisection as an SVG drawing, each step's interval
    a bar narrowing on the root. SVG elements are nodes of the same tree.
  - **C3, the build:** the dependency graph, with each wave's targets grouped,
    drawn from the same facts the builder uses.
- **Checked like the rest:** each page is written to a file and compared with
  `expected/NAME.html`; the text output stays as it is.
- **Later, if #270 settles it:** the same tree driving a live page in the
  browser through the WASM build, so the spreadsheet's handler updates the
  page as it is edited. That is #270's third open question, and it is not
  assumed here.

The parslow.net pages (§8) can then show each program beside the page it
makes.

**Status (2026-11-21):** `self_hosting/lib/dom.patlang` is in, with
`dom_selftest.patlang` (building, querying, escaping, script text, a round trip
through `html_scan`, and linear cost over 1,000 to 8,000 rows). The five pages
above are in: each program takes `--page PATH`, and `run_demos.patlang` checks
the page on every engine against `expected/NAME.html`. The parslow.net showcase
pages show each of the five beside its program: the site build fills an
`<iframe data-source-page="showcase/expected/NAME.html">` with that file, sandboxed
with no permissions, so the site shows the page the gates checked (built locally,
not yet published). Moving the existing
builders (`lib/html.patlang`'s callers: `tools/build_portfolio.patlang`, the
GUI examples and the graph tools) onto the tree
is #270's first open question, still for the owner; the live page in the
browser is its third.

## 6. Where they live and how they are checked

- **Directory:** `showcase/NAME.patlang`, with `showcase/expected/NAME.txt` and
  `showcase/README.md`. The README has the paradigm table above and one row per
  program, with a link to its write-up.
- **Runner:** `self_hosting/tools/run_demos.patlang` gains a directory argument
  (it reads `demos/` only today), so the runner isn't duplicated. A gates suite `showcase` (one unit per program) declares
  `["dir", "showcase"]` as its input. The repository check that every demo is listed
  covers `showcase/` too.
- **Engines:** interpreted and compiled on Windows; Linux under WSL (a
  `showcase_linux` suite, and a `demos_linux` one for the existing demos, which
  Stage 3 of the Linux work has not added yet); WASM under Node for the programs
  that use no sockets or processes.
- **Write-ups:** each program's header holds a short version; the longer
  comparison goes in `showcase/README.md`, beside the sketch in
  `showcase/compare/` (§8), and it is checked as §1 says.
- **Test first**, as for anything else: the expected output is written from what
  the program should show, it fails before the program exists, and passes after.

## 7. Order of work

1. The infrastructure: runner argument, gates suite, repository check, README
   skeleton.
2. P1, P2, P3 and P4: the four that make the clearest case.
3. The rest of Phase 1, two or three at a time, gates after each batch.
4. Phase 2, then the Phase 3 guides.

## 8. Decisions (2026-11-20)

- **Directory:** `showcase/`, as §6 has it.
- **Readers:** people who might take up PatLang. Each program reads on its own with
  no PatLang background: a header saying what the problem is and why this
  combination solves it, comments where the code does something unusual, and no
  technique that only a PatLang user would follow. That favours the shorter end of
  §1's 100 to 300 lines.
- **Comparison sketches are published.** Each program gets its counterpart in the
  most natural other language for the problem (Python for most; Prolog for the logic
  programs; Rust or C for the constant-time one), in `showcase/compare/NAME.EXT`.
  Each sketch:
  - runs, and its output is checked against the PatLang program's where they
    compute the same thing (a gates unit when the language's tool is on the
    machine, failing by name through `has_program` when it is not);
  - is written as a competent programmer in that language would write it, with its
    idiomatic libraries (`fractions`, `asyncio`, a Prolog's own constraint library);
    a sketch built to lose makes the whole comparison worthless;
  - stops at the part that shows the difference, and says where it stops.
  The write-up compares what each needed (lines, libraries, what had to be built by
  hand), with figures, and says where the other language does better.
- **A site:** pages on parslow.net, in the PatLang topic
  (`D:\Projects_Organized\parslow-soft-editorial`, which has its own CLAUDE.md to read
  first, and whose sidebar needs `subtopic_groups` as well as `articles`). One page
  per program or per small group: the problem, the PatLang program, the comparison
  sketch beside it, and its output. Each page takes its code from `showcase/`, not
  a copy, so the pages show what the gates checked. Building those pages is a phase
  of its own, after the programs it shows are in the gates.

## 9. Order of work, with the decisions

1. The infrastructure (§7 step 1), plus `showcase/compare/` and its gates units.
2. P1 to P4, each with its comparison sketch.
3. The first parslow.net pages, for P1 to P4, to settle the page layout before the
   rest are written.
4. The rest of Phase 1, then Phase 2 and the Phase 3 guides, adding pages as each
   batch passes the gates.
5. The DOM library (#270), then Phase 4's pages, P4's first.
