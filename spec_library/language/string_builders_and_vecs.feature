Feature: string builders and vecs are values (docs/plans/general-refcounting.md, 6e/6f)

  `sb_new()` and `vec_new()` return values of their own kind, "string_builder"
  and "vec", freed with their last reference. A copy of one names the same
  builder or vec, and `==` compares identity. They used to be integer handles
  into tables that only grew, in both engines, so every builder and vec a
  program made stayed allocated until it exited.

  Scenario: a string builder and a vec have their own type and identity, under both backends
    Given the program
      """
      let b = sb_new()
      sb_push(b, "ab")
      let b2 = b
      sb_push(b2, "cd")
      print(sb_str(b))
      print(type_of(b))
      print(b == b2)
      print(b == sb_new())
      let v = vec_new()
      vec_push(v, 1)
      let w = v
      vec_push(w, 2)
      print(vec_len(v))
      print(type_of(v))
      let snap = vec_to_list(v)
      vec_set(v, 0, 9)
      print(snap)
      print(vec_to_list(v))
      """
    When it runs interpreted and compiled
    Then both print
      """
      abcd
      string_builder
      true
      false
      2
      vec
      [1, 2]
      [9, 2]
      """

  `str_intern(s)` returns `s` itself: the string, not an integer handle into a
  table that only grew. What `sc_len`, `sc_code`, `sc_char` and `sc_substr` need
  to stay O(1) per call is cached per string and freed with it.

  Scenario: an interned string is a string, under both backends
    Given the program
      """
      let h = str_intern("ab" + "cd")
      print(type_of(h))
      print(h == "abcd")
      print(h + "!")
      print(sc_len(h))
      print(sc_char(h, 2))
      """
    When it runs interpreted and compiled
    Then both print
      """
      string
      true
      abcd!
      4
      c
      """
