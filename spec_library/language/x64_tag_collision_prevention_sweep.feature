Feature: x64 tag-collision PREVENTION sweep (GitHub #49's core ask, #48's fix)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A plain int cannot coincidentally collide with a reserved family tag at zero payload
    Given the program
      """
      let string_tag = 2 shl 60
      let list_tag = 3 shl 60
      let closure_tag = 4 shl 60
      let object_tag = 5 shl 60
      let bigint_tag = (1 shl 60) bor (1 shl 48)
      let rational_tag = bigint_tag bor (1 shl 49)
      let complex_tag = rational_tag bor (1 shl 50)
      let interval_tag = (1 shl 60) bor (1 shl 52)
      print([type_of(string_tag), type_of(list_tag), type_of(closure_tag), type_of(object_tag)])
      print([type_of(bigint_tag), type_of(rational_tag), type_of(complex_tag), type_of(interval_tag)])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [int, int, int, int]
      [int, int, int, int]
      """

  Scenario: a nonzero payload on a reserved tag's bits is still a plain int (GitHub #51)
    Given the program
      """
      print(type_of((2 shl 60) + 1))
      print(type_of(((1 shl 60) bor (1 shl 48)) + 1))
      """
    When it runs interpreted and compiled
    Then both print
      """
      int
      int
      """

  Note: the ints are the bit patterns of the old x64 backend's 8 reserved
  family tags (String/List/Closure/Object/BigInt/Rational/Complex/
  Interval), with a zero payload and then a nonzero one. That backend
  misread them as their family (#48, then #51 for a nonzero payload); v2
  keeps an int's representation apart from every other class's, and
  these scenarios keep it so.
