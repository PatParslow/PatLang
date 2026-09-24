Feature: list semantics agree between the interpreter and native x64 (GitHub #113, #145)

  The interpreter treats lists as values: `==` compares their contents, and
  `list_push`/`list_set` never change a list something else still holds. Native x64
  must give the same answers. Each scenario runs one fixture under `pat --ir-run`
  and compiled with `patc1 --x64` and requires the two outputs to match, line for
  line.

  Scenario: structurally identical lists compare equal, and different lists do not, under both backends
    Given lists built by literals, by list_push, and by a function, compared with == and !=, including nested, empty, unequal-length and list-versus-string cases
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same eleven lines, true or false exactly as the interpreter does (GitHub #113: native used to compare lists by pointer identity)

  Scenario: pushing to or setting an element of a list never changes another list, under both backends
    Given the two repros from the issue, an older list pushed to twice and a set on a stale version, then 6000 deterministic random steps of copy, push, set and read over eight aliased lists
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print identical output, and the first eight lines are the values the interpreter gives for the repros (GitHub #145: native mutated shared storage in place)
