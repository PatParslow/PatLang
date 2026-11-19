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

  Scenario: a thread calls its closure with the arguments that follow it
    Given closures taking two parameters, none and a list, each spawned with that many arguments
    When each thread's result is taken
    Then each is what its closure returned for those arguments

  Scenario: a thread started with the wrong number of arguments stops the program
    Given a closure taking two parameters, spawned with one
    When the program runs
    Then it stops before the thread starts, as a failed precondition of the closure, naming both numbers

  Scenario: threads call a function together, the first time it has been called
    Given a function that calls 8 others, none of them called before
    When parallel_map runs it on 16 threads
    Then each thread gives what one thread alone would give

  Scenario: a handler that yields on a fiber does not hold back its event elsewhere
    Given a handler for ping that yields when it runs on a fiber
    And a fiber that raises ping
    When the fiber is resumed, the program raises ping while the fiber waits, and the fiber is resumed again
    Then the handler ran for the fiber, for the program while the fiber waited, and for the program after

  Scenario: a fiber is resumed as fast among 2000 paused fibers as among 125
    Given 125 fibers, then 2000, each paused at its first yield
    When each is resumed, then run to its end
    Then each hands its values in and out and none is left alive, and a resume among the 2000 costs no more than about four times the cycles of one among the 125

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

  Scenario: threads read files and print numbers together
    Given 8 threads, each reading its own length of one file 400 times and printing a number of seven copies of its own digit each time
    When parallel_map runs them
    Then every read gives the length asked for, and every number is printed whole

  Scenario: threads change the runtime's tables together
    Given 4 workers, each writing 50 virtual files 100 times over, appending to a file of its own 5000 times and adding an action
    When parallel_map runs them
    Then every file holds its last write, every append is there, and every action can be planned

  Scenario: threads waiting on one listener at once each get their answer
    Given a listener, and 3 threads that each wait on it with tcp_accept_timeout for 20, 30 and 40 ms, 20 times over
    When a client then connects while the program waits in tcp_accept
    Then every timed wait gives -1, and tcp_accept gets the client and what it sent

  Scenario: a fiber that is running cannot be resumed
    Given a fiber whose function resumes the fiber it is running in
    When it runs
    Then the program stops at that resume, saying the fiber is already running, and nothing after it runs

  Scenario: a budgeted block costs little per iteration and still yields near its deadline
    Given 2 million cheap iterations, plain and in a budgeted block, and a block of 1 ms iterations given 50 ms
    When each runs, the slow one continued until done
    Then the budgeted loop takes no more than twenty times the plain one, the best of three runs each, the slow block first yields between 25 and 80 ms, and all its iterations run

  Scenario: more threads than processors do not hold off a lock's next holder
    Given 32000 virtual files written by 4 threads, and then by 16
    When each group runs
    Then the 16 take no more than about four times as long as the 4

  Scenario: a vec belongs to one thread at a time
    Given 4 threads each pushing 50000 values onto one vec
    When their results are taken
    Then every push is there, or the program stops saying a vec was changed by one thread while another was using it
