Feature: when / emit (event system)

  Scenario: emit runs the matching handler, once per call
    Given `when tick do ... end` incrementing a counter
    When emit("tick", 5) then emit("tick", 7) are both called
    Then the counter is 2 -- the handler ran once per emit

  Scenario: event_name and event_data are implicit handler parameters
    Given the handler body reads `event_name` and `event_data` directly, with no declaration
    When an event fires
    Then event_name is the string passed as emit's first argument, event_data is the payload (second argument)

  Scenario: the handler is a real closure, capturing enclosing lets
    Given `let base = 100` declared before the when-block, referenced inside it
    When the handler runs
    Then it sees the real captured value of base (100), combined correctly with the live event_data each time (100+5=105 on the first call, 100+7=107 on the second) -- not a stale or hardcoded value

