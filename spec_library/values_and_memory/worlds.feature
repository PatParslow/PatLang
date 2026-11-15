@language
Feature: worlds (spec 1.15)

  Scenario: code in a world sees the world's state and none of the caller's
    Given a program with a fact, a named object, a class, a handler and a virtual file of its own, and a function it reaches by name
    When code in a new world looks for each, adds its own, and the program looks again
    Then the world sees none of the program's, the program sees none of the world's, a second call in the world sees what the first added, and the function is reached by name in the world too

  Scenario: what a world prints is kept in the world
    Given a world whose code prints two lines
    When the program prints before and after calling it
    Then standard output has only the program's lines, and world_output gives the world's

  Scenario: a stop in a world ends the call and not the program
    Given worlds whose code stops by a failed require, by exit_with(5) and by a call to a name nothing declares, each after printing a line
    When the program calls each
    Then each call gives stopped and the exit code, the world's output has the line and what the stop said, and the program goes on

  Scenario: a fiber runs in the world it was made in
    Given a fiber made in a world and a fiber made by the program, each reporting the facts it sees
    When the program resumes the world's fiber and code in the world resumes the program's
    Then each fiber sees the facts of the world it was made in

  Scenario: a thread runs in the world of the code that started it
    Given code in a world that adds a fact and starts a thread that reports it
    When the thread's result is taken
    Then the thread saw the world's fact

  Scenario: a stop on a thread started in a world ends that thread
    Given code in a world that starts a thread which prints a line and stops by exit_with(9)
    When the code takes the thread's result and prints a line of its own
    Then the call gives stopped with code 9, the world's output has both lines, and the program goes on

  Scenario: a thread a stop in a world ends has finished
    Given code in a world that starts a thread which stops by exit_with(9)
    When the code polls the thread until it has finished, then takes its result
    Then the call gives stopped with code 9, thread_poll said the thread had finished, and its result was unit

  Scenario: a stop in a world gives back what the frames it ends held
    Given a loop of N iterations that each call code in a new world which holds a list of 1000 ints on each of three frames and then stops, directly, inside a fiber, or on a thread the code started
    When it runs for N and for 10N iterations
    Then for each, the peak memory does not grow as more stops end frames

  Scenario: a fiber paused in a world is unwound when the world is freed
    Given a loop of N iterations that each call code in a new world which starts a fiber that holds a list of 1000 ints and yields, and then free the world
    When it runs for N and for 10N iterations
    Then the peak memory does not grow as more paused fibers are freed with their worlds

  Scenario: a program that asks for every runtime function by name runs the same interpreted
    Given a program that declares runtime_functions_by_name(), as one that runs source in a world through the interpreter does, and reaches a runtime function by name in the program and in a world
    When it runs on the interpreter and compiled
    Then both print the same lines

  Scenario: worlds nest
    Given code in a world that makes a second world and calls into it
    When each adds a fact and reports what it sees
    Then each world sees only its own facts, and the inner world's output is in the inner world

  Scenario: a world's step budget stops it
    Given a world with a budget of 1000 steps whose code spends a step on every iteration of a loop that never ends
    When it is called
    Then the call gives stopped with code 78, and the world's output says the budget of 1000 steps is exhausted

  Scenario: worlds that are freed hold no memory
    Given a loop of N iterations that each make a world, call code in it that adds facts, a class and a file, and free it
    When it runs for N and for 10N iterations
    Then the peak memory does not grow as more worlds are made and freed
