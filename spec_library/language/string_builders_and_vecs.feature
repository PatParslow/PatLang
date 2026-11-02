Feature: string builders and vecs are values (docs/plans/general-refcounting.md, 6e/6f)

  `sb_new()` and `vec_new()` return values of their own kind, "string_builder"
  and "vec", freed with their last reference. A copy of one names the same
  builder or vec, and `==` compares identity. They used to be integer handles
  into tables that only grew, in both engines, so every builder and vec a
  program made stayed allocated until it exited.

  Scenario: a string builder and a vec have their own type and identity, under both backends
    Given a builder pushed to through two names, a vec pushed to through two names, identity comparisons, and a vec_to_list snapshot taken before a vec_set
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same nine lines: the shared contents, "string_builder" and "vec" from type_of, true for a copy and false for another builder, and the snapshot unchanged

  `str_intern(s)` returns `s` itself: the string, not an integer handle into a
  table that only grew. What `sc_len`, `sc_code`, `sc_char` and `sc_substr` need
  to stay O(1) per call is cached per string and freed with it.

  Scenario: an interned string is a string, under both backends
    Given a string built by + and interned, then compared, concatenated, and read with sc_len and sc_char
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same six lines, starting with "string" from type_of
