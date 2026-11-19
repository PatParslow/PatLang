Feature: match / case pattern matching (issue #44)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print, or what both say as they stop (spec_steps_program.patlang).

  Scenario: Literal, binding and comparison patterns
    Given the program
      """
      make a function called classify takes x returns r
        match x do
          case 0 then
            return "lit0"
          case "hi" then
            return "greeting"
          case > 10 then
            return "big"
          case n then
            return "bound:" + n
        end
      end
      print(classify(0))
      print(classify("hi"))
      print(classify(3))
      print(classify(20))
      """
    When it runs interpreted and compiled
    Then both print
      """
      lit0
      greeting
      bound:3
      big
      """

  Scenario: Tagged-list patterns destructure and bind, through two levels, and fall through to the wildcard
    Given the program
      """
      make a function called describe takes pair returns r
        match pair do
          case ["Ok", v] then
            return "ok:" + v
          case ["Err", ["Nested", m]] then
            return "nested-err:" + m
          case _ then
            return "unknown"
        end
      end
      print(describe(["Ok", 5]))
      print(describe(["Err", ["Nested", "boom"]]))
      print(describe(["Err", "flat"]))
      """
    When it runs interpreted and compiled
    Then both print
      """
      ok:5
      nested-err:boom
      unknown
      """

  Scenario: A `when` guard rejects or accepts, using its own pattern's binding
    Given the program
      """
      make a function called guarded takes x returns r
        match x do
          case n when n > 100 then
            return "big-bound:" + n
          case n then
            return "small-bound:" + n
        end
      end
      print(guarded(12))
      print(guarded(200))
      """
    When it runs interpreted and compiled
    Then both print
      """
      small-bound:12
      big-bound:200
      """

  Scenario: A string glob pattern matches via substring/prefix wildcards
    Given the program
      """
      make a function called glob takes s returns r
        match s do
          case *fred* then
            return "glob-hit"
          case _ then
            return "glob-miss"
        end
      end
      print(glob("alfred smith"))
      print(glob("alice"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      glob-hit
      glob-miss
      """

  Scenario: A scrutinee that matches nothing, with no wildcard arm, stops the program
    Given the program
      """
      make a function called pick takes x returns r
        match x do
          case 1 then
            return "one"
          case 2 then
            return "two"
        end
      end
      print(pick(1))
      print(pick(99))
      print("not reached")
      """
    When it runs interpreted and compiled
    Then both print, before stopping
      """
      one
      """
    And both stop, saying
      """
      no case matched
      """

  Scenario: A matched arm with no `return` goes on past the match, not back into it
    Given the program
      """
      make a function called side takes x returns r
        match x do
          case 1 then
            return "one"
          case > 2 then
            print("two-plus-side-effect")
          case > 10 then
            return "lots"
        end
        return "fell-through"
      end
      print(side(99))
      """
    When it runs interpreted and compiled
    Then both print
      """
      two-plus-side-effect
      fell-through
      """

  Scenario: A match that ends a function gives the function its value, and an arm's let assigns its named result
    Given the program
      """
      make a function called tail_value takes x returns r
        match x do
          case 1 then
            "one"
          case _ then
            "other"
        end
      end
      make a function called assign_result takes pair returns r
        match pair do
          case [a, b] then
            let r = a + b
          case _ then
            let r = 0
        end
      end
      print([tail_value(1), tail_value(2)])
      print([assign_result([2, 3]), assign_result(9)])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [one, other]
      [5, 0]
      """

  Scenario: A closure's match sees what the closure captured
    Given the program
      """
      make a function called captured takes limit, x returns r
        let f = |y| {
          match y do
            case > limit then
              return "over"
            case n when n == limit then
              return "at"
            case _ then
              return "under"
          end
        }
        return f(x)
      end
      print([captured(10, 11), captured(10, 10), captured(10, 9)])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [over, at, under]
      """

  Scenario: The scrutinee is evaluated once
    Given the program
      """
      make a function called once takes counter returns r
        let scrutinee = |c| {
          vec_set(c, 0, vec_get(c, 0) + 1)
          return 5
        }
        match scrutinee(counter) do
          case 1 then
            return "one"
          case 2 then
            return "two"
          case > 3 then
            return "many"
        end
      end
      let counter = vec_new()
      vec_push(counter, 0)
      print(once(counter))
      print(vec_get(counter, 0))
      """
    When it runs interpreted and compiled
    Then both print
      """
      many
      1
      """

  Scenario: A value of another type does not match a literal or a list pattern
    Given the program
      """
      make a function called other_type takes x returns r
        match x do
          case "7" then
            return "text"
          case 7 then
            return "seven"
          case [a] then
            return "list"
          case _ then
            return "other"
        end
      end
      print([other_type(8), other_type("x"), other_type([1, 2]), other_type([1]), other_type(7), other_type("7")])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [other, other, other, list, seven, text]
      """

  Note: an arm whose body does not end in `return` once jumped back to the
  start of the function instead of past the match, looping forever (the
  old self-hosted lowering never patched that jump); and a `when` guard
  was once tested before its pattern's bindings were stored, so it always
  failed. The no-`return` and guard-accepts scenarios are the ones that
  caught them.
