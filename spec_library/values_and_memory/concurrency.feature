@language
Feature: fibers, budgeted blocks and threads (spec 1.8)

  Scenario: a fiber runs until it yields, and each resume hands it a value
    Given a function counter that yields twice and then returns, on a fiber
    And a fiber that starts another fiber and resumes it
    When each is resumed until it ends
    Then each resume gives what it yielded or returned, and it is alive until it has returned

  Scenario: a budgeted block runs until its time is up
    Given budgeted blocks over a loop, with a budget of 1 ms, of 0 ms and of a long time
    When each is run, and a paused one continued from its handle
    Then a block that finishes gives done and its value, one that does not gives paused and a handle, and continuing it reaches the same value

  Scenario: a thread runs a closure on its own, and gives back its result
    Given closures returning an int, a string and a list, each on a thread
    And 8 threads summing different ranges
    When each is polled until it has finished, and its result taken
    Then each result is what its closure returned

  Scenario: threads call a function together, the first time it has been called
    Given a function that calls 8 others, none of them called before
    When parallel_map runs it on 16 threads
    Then each thread gives what one thread alone would give

  Scenario: a finished fiber cannot be resumed
    Given a fiber that has returned
    When it is resumed
    Then the program stops at that call, naming the require clause

  Scenario: only a fiber can yield
    Given a program that is running on no fiber
    When it calls fiber_yield
    Then the program stops at that call, naming the require clause, and fiber_yield's function

  Scenario: a thread's result is taken once
    Given a thread whose result has been taken
    When thread_result is called for it again
    Then the program stops, saying the result has been taken

  Scenario: fibers and threads that end hold no memory
    Given loops of N iterations that each run one of these to its end:
      | a fiber that yields once           |
      | a budgeted block                   |
      | a thread whose result is then taken |
    When each runs for N and for 10N iterations
    Then no concurrent loop's peak memory grows
