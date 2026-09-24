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
