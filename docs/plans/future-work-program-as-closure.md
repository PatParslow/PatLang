# Future work: a program is a closure

A PatLang program would be a closure over its definitions: the functions, classes and constants it
defines form its environment, and the program as a whole is a value that takes its command line and
returns what it returns. The project owner asked for this before, and on 2026-11-08 placed it here as
future work: it is about technical correctness and consistency more than immediate functionality, and
its main gain is that programs can be composed the way closures are.

Nothing here is planned for the current work. It follows the v2 goal
(`docs/plans/v2-implementation.md`), and needs its spec written before it is built.

## The idea

In an ideal program there are no top-level assignments. What sits at top level is definitions, and a
definition is a binding of a particular kind: it never changes, its order does not matter, and
definitions may refer to each other (as `letrec` binds in Scheme). A closure over definitions needs
no rule for when it captures them or what happens when they are reassigned, because they are not.

Read that way, today's meaning is already close. A top-level `let` is a local of the synthesized
`main`, so it is not a top-level assignment at all: it is `main`'s local, written unindented among the
definitions, and a function not seeing it is right, as one function does not see another's locals.
What CLAUDE.md §4.6 records as a recurring mistake is a matter of layout (`main`'s body sitting among
the definitions, so it looks like the program's environment) and one real gap: a definition cannot be
used as a value.

So a program is:

- **an environment of definitions**: its functions, classes and constants, immutable and mutually
  referring; and
- **a closure `|argv| <main's body>`** over that environment, where main's body is the program's
  top-level statements, as now.

### Files, definitions and programs

One file is one environment. Two sibling functions in it are two definitions in that environment, not
two programs: each sees the other whatever their order, so they may be mutually recursive (as calls by
name already are today), and once definitions are values each may pass the other as one.

| a file holds | it is |
|--------------|-------|
| definitions and top-level statements | a program: its definitions, and `\|argv\| <statements>` over them |
| definitions only | a library: an environment with no body |
| statements only | a program with an empty environment |

Run on its own, a definitions-only file does nothing (v2 gives it an empty `main` today); it would
warn that it has no program body, never refuse. Several entry points are one program dispatching on
its command line, or several program files including one library.

### Includes and modules

Two mechanisms, for two jobs (agreed with the owner on 2026-11-08):

- **`include` joins the environment**, as its text does today, unchanged in meaning. It splits one
  environment across files, so definitions in an included file and in the includer may be mutually
  recursive.
- **A module is a separate closure.** `import "../zip/zip.patlang" as zip` gives the importer one
  value, `zip`, whose definitions it reaches by name (`zip.read_archive(...)`). A module:
  - holds definitions only: a module with top-level statements is refused, which makes "no top-level
    assignments" strict where nothing existing depends on it;
  - sees only its own definitions and what it imports itself, never its importer's, so its
    dependencies are all in its own text;
  - is shared: its definitions never change, so every importer of one module gets the same
    environment, compiled once;
  - shows its importers only what its `export` list names (agreed 2026-11-08).

  Modules give each package its own names: with includes alone, every package's functions share one
  flat namespace, and two packages defining the same function cannot be used in one program.

#### Exports are contracts

A module's `export` list is its interface, and each exported function carries its `require` and
`ensure` clauses, so the interface says what a caller must provide and what it may rely on. Two
versions of a module can then be compared mechanically, function by function: a newer export that
requires no more and ensures no less is compatible (an importer written against the old contract
still holds), and anything else is a breaking change that needs a new major version. The package
manager can check that a release's version number agrees with that comparison, as far as clauses
can be compared (syntactically equal, or one implying the other where the checker can show it).

#### Import cycles, by name

Languages refuse import cycles mostly because of initialisation order: a module half run when its
importer first reads it. A PatLang module has no body, only definitions, so there is no order to get
wrong, and cycles can be allowed:

- An import binds a name to the module, and a qualified reference (`b.f`) is resolved by name when
  the program is put together, never by running anything. Modules in a cycle are built in two steps,
  as a `letrec` is: every module's value exists first, then every definition is filled in.
- Each module can be compiled against the other's `export` list alone, which acts as its declared
  interface, so a cycle does not force the modules to be compiled as one.
- Constants are the one exception: a constant defined from another module's constant, in a cycle that
  comes back to itself, has no value. Cycles through functions are allowed; a cycle through constant
  definitions is refused, naming the constants in it.

This also keeps packages as they are: the resolver accepts dependency cycles today, and modules would
not take that away.

To settle in the spec: the export syntax and where contracts are written for exported classes and
constants; the qualified-name syntax; and the compatibility checker's rules for comparing clauses.

## Decided (2026-11-08)

- A program receives its command line, the list `argv()` gives today, and nothing more. Files, the
  network, environment variables and the stores of #252 are reached through the ordinary primitives,
  as now.
- A program returns whatever it returns. Run on its own, it behaves as now; composed, its caller gets
  the value.
- No existing program changes meaning.
- A top-level `let` keeps its meaning: a local of the program's body, invisible to functions.

## What changes

1. **A named definition is a value.** Its bare name, used where a value is expected, is that function
   (or class), as a closure is: it can be stored, passed to `parallel_map`, `thread_spawn` or
   `action_bind`, kept in a list, and called through a variable. Today a function is passed to these
   by its name as a string, or replaced by a closure literal (CLAUDE.md §4.6).
2. **Constants.** A top-level definition of an immutable value (syntax to settle, for example
   `define limit = 4096`) joins the environment, so functions can use it. It never changes, so
   capturing it by snapshot or by reference is the same.
3. **The program is a value.** Another program can call it with a command line and get its result.
4. **A warning, never a refusal**, for a top-level `let` that could be a constant or could move into an
   explicit `main`, to steer programs towards having no top-level assignments.

## Why no existing program changes meaning

Both v2 engines refuse every program that the first two changes give meaning to. Checked on
2026-11-08:

- a function naming a top-level binding:
  ```patlang
  let greeting = "hello"
  make a function called show returns ok
    print(greeting)
    return true
  end
  show()
  ```
  the v2 interpreter stops with `error: undefined variable greeting`; v2 refuses to compile it with
  `v2 error: undefined variable greeting`;
- a named function used as a value:
  ```patlang
  make a function called double takes x returns y
    return x * 2
  end
  let f = double
  print(f(4))
  print(parallel_map(double, [1, 2, 3]))
  ```
  both engines give `undefined variable double`.

Top-level `let` keeps its meaning, so the first case stays refused: a function still cannot see a
top-level `let`, only definitions. A name that already means something inside a function (its own
parameter or local, a function, a built-in) keeps that meaning; a constant with the same name as a
function or built-in is refused when it is defined, so no call's meaning can shift.

Done means: every existing suite (Part 1 and 2, engines agree, language, match, block model, the
packages' specs) passes unchanged on both v2 engines, and the scenarios below pass.

## Questions left for the spec

- **Constant syntax**, and which values may be constants (any value, or only those with no mutable
  parts: no vec or string builder handles).
- **Calling a program.** By path (compiled together, or loaded at run time) or by including it as a
  value; and how its output relates to the caller's (today both print to the same standard output).
- **Modules.** The export rule, the qualified-name syntax, and how a module is found (a path, as
  `include` uses, or a package name the package manager resolves).
- **Top-level registrations.** `when` handlers, signal handlers and `rule` declarations at top level
  are statements of the program's body that register with stores; with #253 they do so through
  `using`.
- **Compilation.** A definition used as a value needs an addressable function and a closure object in
  both v2 engines (the apply table already holds functions reached by name). Its cost is to be
  measured.

## Scenarios

- A named function stored in a variable, kept in a list, and passed to `parallel_map` and
  `thread_spawn`, gives the same results as a closure literal doing the same.
- Two mutually recursive functions, each passed as a value, still call each other.
- A constant is visible to every function, whatever order the definitions are in.
- A function still cannot see a top-level `let` (the refusal stays, with an error naming the
  binding and suggesting a constant or a parameter).
- A constant named like a built-in or a function is refused where it is defined.
- A program run on its own prints and exits as before; called from another program with a command
  line, it returns its value to the caller.
- A program passed to `parallel_map` runs once per command line.
- Two modules each defining a function of the same name are imported into one program, and each
  qualified call reaches its own module's function.
- A module with a top-level statement is refused; a module cannot see its importer's definitions,
  and an importer cannot see a module's definitions that are not in its `export` list.
- Two modules importing each other call each other's exported functions, mutually recursively; a
  cycle through constant definitions is refused, naming the constants.
- A newer module version whose exports require more or ensure less is reported as breaking.
- A module imported by two importers is one environment (its definitions compiled once).
- An `include`d file's definitions and the includer's are mutually recursive, as today.

## Relations

- Lexical `using` blocks ([#253](https://github.com/PatParslow/PatLang/issues/253)) do not depend on
  this, and keep their rule of not reaching into named function definitions.
- The removal of ambient globals and the explicit stores of
  [#252](https://github.com/PatParslow/PatLang/issues/252) are separate steps in the same direction:
  with them, nothing at top level but definitions holds state.
