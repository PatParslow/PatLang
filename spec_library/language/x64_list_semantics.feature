Feature: list semantics agree between the interpreter and native x64 (GitHub #113, #145)

  The interpreter treats lists as values: `==` compares their contents, and
  `list_push`/`list_set` never change a list something else still holds. Native x64
  must give the same answers. Each scenario carries its program, runs it
  interpreted and compiled, and says what both print (spec_steps_program.patlang).

  Scenario: structurally identical lists compare equal, and different lists do not, under both backends
    Given the program
      """
      let a = ["rare_atlas", "branch_b"]
      let b = list_push(list_push([], "rare_atlas"), "branch_b")
      print(a == b)
      let e = ["no"]
      let f = ["no"]
      print(e == f)
      make a function called mk takes x returns r
        return ["hit", x]
      end
      print(mk("foo") == ["hit", "foo"])
      print([[1], [2, 3]] == [[1], [2, 3]])
      print([1, 2] != [1, 2])
      print(["a"] == ["b"])
      print(["a"] == ["a", "b"])
      print([1, 2] != [1, 3])
      print([] == [])
      print(["a"] == "a")
      print(a == a)
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      true
      true
      true
      false
      false
      false
      true
      true
      false
      true
      """

  Scenario: pushing to or setting an element of a list never changes another list, under both backends
    Given the program
      """
      include "{root}/self_hosting/tools/spec_fixtures/x64_list_aliasing.patlang"
      """
    When it runs interpreted and compiled
    Then both print
      """
      [10, 20]
      [99, 20]
      20
      21
      [1, 2, 3]
      [1, 2, 3, 4]
      [1, 2, 3, 5]
      [100, 2, 3, 4]
      853557
      [781]
      [101]
      [264, 614, 586, 39, 774, 259]
      [264, 614, 472, 412, 525, 545]
      [264, 614, 472, 412, 525, 867, 305]
      [101, 861]
      [264, 614, 472, 412, 525]
      [264, 614, 586, 39, 460, 611]
      walk done
      """

  The first eight lines are the two repros from the issue (an older list
  pushed to twice, a set on a stale version); the rest is a checksum over
  6000 deterministic random steps of copy, push, set and read over eight
  aliased lists, and the eight lists at the end (GitHub #145: native
  mutated shared storage in place).
