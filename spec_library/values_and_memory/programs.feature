@language
Feature: what functions, commands and includes give (spec 1.13)

  Scenario: a function that ends without return gives the value of its last statement
    Given functions ending in an expression, a call, a let, an if, a while, and nothing
    When each is called
    Then each gives what spec 1.13 says, and an if or while that ran nothing gives unit

  Scenario: the name unit is the unit value, unless the program binds it
    Given a program that writes unit, and binds unit as a parameter and as a variable
    When it runs
    Then unit is the value a function with no statements gives, and a bound unit is the program's own

  Scenario: exec_capture gives what a command wrote to both of its outputs
    Given a command that writes to standard error and to standard output
    When exec_capture runs it
    Then it gives both

  Scenario: a using block naming a role with no store is refused when compiling
    Given a program with `using kb as planner do ... end`
    When it is compiled
    Then the error names the unknown role, and nothing runs

  Scenario: list_dir of a path with no directory gives an empty list
    Given a path with no directory at it, and a directory with files
    When list_dir reads each
    Then the first gives [] and the program goes on, file_exists says the path is missing, and the second gives entries

  Scenario: path_absolute gives a path in full, with / between its parts
    Given a path relative to the current directory, the same path through .., and the full path itself
    When path_absolute reads each
    Then each gives the same full path, longer than the relative one, ending in it, naming a file that exists, with no backslash

  Scenario: a program reads how many processors the machine has, how busy they have been, and its memory
    Given cpu_count, cpu_times and memory_status, cpu_times read 100 ms apart
    When each is called
    Then there is at least one processor, the times grow between the readings, and the free memory is no more than the total

  Scenario: exec_peak_memory and exec_measured give a command's output and its peak memory
    Given a command that writes to both outputs, once exiting 0 and once exiting 3
    When exec_peak_memory runs each, and exec_measured the second, a command that succeeds, and a command whose child commits several hundred MB
    Then it gives standard output, standard error only from the failure, and a peak above 0
    And exec_measured gives the two outputs apart, false then true for the exits, and a peak above 0
    And exec_measured's peak counts the child's memory, where exec_peak_memory's is the command's own

  Scenario: the runtime has the stage-0 shims
    Given add, multiply and subtract of ints and of rationals, and calculate, calculate_result, get_value, process and validate of an int, a string and a list
    When each is called
    Then add, multiply and subtract give the sum, product and difference, and the others give 0 or true

  Scenario: progress_report keeps the latest status, and plan_incremental and action_clear work on the actions
    Given a status read before any report and after two, and a one-action plan found with plan and with plan_incremental, then the actions cleared
    When the program runs
    Then the status is empty, then the second report; both plans are the action, and after action_clear there is no plan

  Scenario: rules live in stores, which goals draw from together and solve into
    Given a store with one fact added twice through two holders, rules declared in a named store and read with from, two stores each holding q, a store solved into twice, a plan from a store's facts, a contract checked, the default store cleared and a named store deleted
    When the program runs
    Then each prints what spec 1.13 says of stores

  Scenario: plan finds a cheapest plan for many goals, and says there is none only when none exists
    Given a chain of two builds and 10 goals each needing the second, a goal no action reaches, two routes of different cost, and 40 then 80 goals timed
    When plan is asked for each
    Then the builds come first and every goal is met, the unreachable goal gives [], the cheaper route is taken, and twice the goals take no more than about nine times as long

  Scenario: the logic engine's work grows with what each call needs
    Given 4,000 and then 8,000 rules added, a bound goal solved before and after 20,000 rules of another predicate are added, and goals with 4,000 and 8,000 solutions
    When a program times them
    Then twice the rules take no more than about three times as long, the other predicate's rules cost the goal little, and twice the solutions take no more than about three times as long

  Scenario: a file reached by two includes is included once
    Given a program whose two included files both include a third
    When it runs
    Then the third file's statements run once, before the files that include it

  Scenario: a program's function may have a name the runtime has
    Given a program defining to_s, list_len and emit
    When it calls them directly, from a closure and by name
    Then each call reaches the program's function, and the runtime goes on using its own

  Scenario: two of a program's files defining one name is an error
    Given a program and a file it includes that define one function name
    When the program is given
    Then both engines report that the name is declared twice, and nothing runs

  Scenario: a program's value is not printed
    Given a program whose last statements are a call whose value nothing uses, and an int
    When it runs
    Then it prints only what it printed itself

  Scenario: a call naming a function with the wrong number of arguments is refused
    Given a function taking two arguments, and one taking one and rest, each called with too few or too many, and a closure called with nine
    When the program is compiled
    Then both engines refuse it, naming the function and both numbers, and that a closure takes at most 8, and nothing runs

  Scenario: a closure called with the wrong number of arguments stops the program
    Given a closure taking two parameters, called with two and then with one
    When the program runs
    Then the first call gives its value, and the second stops the program as a failed precondition of the closure, naming both numbers

  Scenario: a function called by name takes exactly its arguments, and rest any further ones
    Given apply and parallel_map of a function taking two arguments and of one taking one and rest
    When each is called
    Then each gives its value, rest holding the further arguments as a list

  Scenario: a function called by name with the wrong number of arguments stops the program
    Given apply of a function taking two arguments, with one
    When the program runs
    Then it stops as a failed precondition of the function, naming it and both numbers

  Scenario: a closure whose last parameter is named rest takes any further arguments
    Given a closure taking one parameter and rest, called through a variable with one and with three arguments, and on a thread with two
    When each is called
    Then rest holds the further arguments as a list each time, as for a function

  Scenario: a closure taking rest, called with too few arguments, stops the program
    Given a closure taking one parameter and rest, called with none
    When the program runs
    Then it stops as a failed precondition of the closure, saying it takes at least 1 argument
