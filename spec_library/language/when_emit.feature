Feature: when / emit (event system)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). A handler is declared at the top
  level, where handlers are registered once, statically.

  Scenario: emit runs the matching handler, once per call
    Given the program
      """
      class Log {
        field ticks = 0
      }
      new("Log", "log")
      when tick do
        send("log", "set", "ticks", get("log", "ticks") + 1)
      end
      emit("tick", 5)
      emit("tick", 7)
      print(get("log", "ticks"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      2
      """

  Scenario: event_name and event_data are implicit handler parameters
    Given the program
      """
      when ping do
        print([event_name, event_data])
      end
      emit("ping", "payload42")
      """
    When it runs interpreted and compiled
    Then both print
      """
      [ping, payload42]
      """

  Scenario: the handler is a real closure, capturing enclosing lets
    Given the program
      """
      let base = 100
      when combine do
        print(base + to_num(event_data))
      end
      emit("combine", "5")
      emit("combine", "7")
      """
    When it runs interpreted and compiled
    Then both print
      """
      105
      107
      """
