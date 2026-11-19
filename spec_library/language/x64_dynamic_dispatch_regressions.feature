Feature: x64 dynamic-dispatch regressions (#98/#100/#85) -- a real interp-vs-x64/interp-vs-native comparison

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: band of a Float stops the program on both engines, as spec 1.11 says (#98)
    Given the program
      """
      make a function called bandtest takes f returns done
        print(f band 255)
      end
      bandtest(1)
      bandtest(1.0 + 61.0)
      """
    When it runs interpreted and compiled
    Then both print, before stopping
      """
      1
      """
    And both stop, saying
      """
      this operation does not take a float
      """

  Scenario: string + bool, and print()'s own Unit return (#100, #85)
    Given the program
      """
      print("bool concat: " + true)
      print(false + " tail")
      let u = print("noop")
      print(type_of(u))
      print("prefix:" + u)
      """
    When it runs interpreted and compiled
    Then both print
      """
      bool concat: true
      false tail
      noop
      unit
      prefix:
      """

  Scenario: printing gives genuine Unit, not the old truthy-Bool placeholder (#63 item 2)
    Given the program
      """
      let r1 = print("a")
      print(type_of(r1))
      let r2 = print(true)
      print(type_of(r2))
      let r3 = print(3.0)
      print(type_of(r3))
      """
    When it runs interpreted and compiled
    Then both print
      """
      a
      unit
      true
      unit
      3
      unit
      """

  Scenario: sqrt/sin/cos/pow print their real numeric result, not a garbage int (#109)
    Given the program
      """
      print(sqrt(9.0))
      print(sqrt(2.0))
      print(sin(0.0))
      print(cos(0.0))
      print(pow(2.0, 10.0))
      print(floor(2.9) + sqrt(4.0))
      """
    When it runs interpreted and compiled
    Then both print
      """
      3
      1.4142135623730951
      0
      1
      1024
      4
      """

  Note: none of these four were catchable by the Rust cargo test suite
  (it had no tests that invoked --x64 at all) or, for #85 and the
  related #83/#99 floor() regression, by interpreter-only verification,
  which never exercises the compiled path. This is why these scenarios
  insist on a compiled binary's actual output as well as the
  interpreter's.
