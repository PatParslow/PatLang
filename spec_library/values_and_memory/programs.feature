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

  Scenario: the console a key at a time, and the directory the program runs in
    Given standard input that is not a console, and the directory the program starts in
    When console_raw_enable, console_raw_disable, cwd and set_cwd run
    Then raw mode gives -1 and changes nothing, the echoes write with no line end, and cwd follows set_cwd there and back, unchanged by a directory that is missing

  Scenario: a path holding the character with code 0 stops the program before the system sees it
    Given write_file of a path whose name is followed by code 0 and .tmp
    When it runs
    Then the program stops saying the path holds code 0, and no file named by the part before it is made

  Scenario: vfs_flush_to_disk writes only inside its directory
    Given a virtual file pkg/../../v2_rt_paths_escaped.txt, and another pkg/sub/../ok.txt
    When each is flushed to a directory of its own
    Then the first stops the program naming the file, with nothing written, and the second is written as pkg/ok.txt with no pkg/sub made

  Scenario: path_absolute never gives a wrong path
    Given a relative path of about 6000 characters
    When path_absolute reads it
    Then it gives the current directory followed by the path, or stops saying the system could not make it absolute

  Scenario: TCP connects only to this machine
    Given a listener, and tcp_connect to 127.0.0.1, to localhost, to 10.0.0.1, to 1.2.3 and to 127.0.0.300, tcp_try_connect to the listener and to a port nothing listens on, and tcp_try_write to a peer that has closed
    When each is tried
    Then the first two connect and carry what is written, 10.0.0.1 stops the program saying it is not this machine, the others stop it saying they are not addresses, tcp_try_connect connects to the listener and gives -1 for the other, and tcp_try_write comes to give false while the program goes on

  Scenario: the store forms, a bool array's elements and a builder's length give what they give
    Given a bool array set at 3 and 69, a builder holding four characters in five bytes, a store given facts with fact_in, planned from with plan_with_state_in, and emptied with rules_clear_in
    When each is read
    Then the array reads true at 3 and 69 and false at 4, the builder holds 5 bytes, query_in counts the store's facts and not the default store's, the plan is one step reaching four facts, and the emptied store holds none while the default store keeps its rule

  Scenario: a child inherits its standard handles and nothing else
    Given a program that listens on a port, spawns a child that runs on for about six seconds, prints the port and ends
    When another program captures its output
    Then the capture ends in well under the child's six seconds, and the port can be listened on again while the child still runs

  Scenario: is_alive changes nothing, so a wait after it gives the exit code
    Given a program that spawns a child exiting with code 3, and asks is_alive until it says false
    When it then asks is_alive again and waits for the child
    Then is_alive says false again, and the wait gives 3

  Scenario: a port is free once the program that listened on it has ended
    Given a program that listens on a port, takes a connection, closes its end first and ends
    When another program listens on that port straight after, and a third tries a port its own listener holds
    Then the second gets the port, and the third is refused

  Scenario: TCP and names beyond this machine only once the program declares tcp_allow_remote()
    Given a program that asks dns_resolve for a name, one that first declares tcp_allow_remote(), and a DNS server on this machine
    When each resolves names and connects
    Then the first is stopped, the second resolves names and connects to one, and dns_query reads the server's records, its NXDOMAIN and its CNAME, and gives no addresses where nothing answers

  Scenario: tcp_read_status tells data, a wait and the peer's end apart
    Given a connection whose peer writes one byte, waits for an answer, then closes
    When tcp_read_status reads it three times
    Then it gives the byte as data, a wait while the peer waits, and the end once the peer has closed

  Scenario: a program named with no directory is found through PATH alone
    Given a directory holding a cmd.exe that prints planted, and a program run from it that captures cmd /c echo from the system
    When the program runs
    Then it prints from the system, and the cmd.exe in the directory does not run

  Scenario: dir_files gives a directory's files with their sizes and when each was written
    Given a directory with a four-byte file written first, a seven-byte file written 50 ms later, and a subdirectory
    When dir_files reads it, and a path with no directory at it
    Then it gives the two files by name with their sizes, the later one's written the larger, no subdirectory, and [] for the missing path

  Scenario: the runtime's primitives and rt_ functions are the runtime's alone
    Given a program, not a quiet file, that calls runtime_state, mem_load and rt_alloc, and another that names rt_str_alloc as apply's function
    When each is built or interpreted
    Then each is refused before anything runs, naming every such call

  Scenario: a name made at run time reaches no runtime rt_ function
    Given a program that makes the name rt_str_alloc at run time and applies it
    When it runs on either engine
    Then the lines before it run, and it stops as for a name nothing declares, the same on both

  Scenario: a NaN is ordered against nothing
    Given a NaN made by dividing 0.0 by itself, and ordinary floats, ints and strings
    When each is compared with == != < <= > and >=
    Then every comparison with the NaN is false but !=, which is true, and the others compare as before

  Scenario: each ordering operator is a method of its left operand's class
    Given a class defining only <=, two classes each defining > with a different answer, and a class defining only <
    When objects of each are compared
    Then <= is sent as itself, a > b goes to a's class, and > on the class with only < stops the program naming > and the class

  Scenario: a method named == is refused
    Given a class declaring a method named ==
    When the program is built or interpreted
    Then it is refused before anything runs, saying objects compare by identity

  Scenario: cpu_cycles counts this thread's work, not the time it waits
    Given cpu_cycles read before and after some work, across a 200 ms sleep, and around four times the work
    When the counts are compared
    Then the count grows with work, a sleep adds less than a tenth of what the work did, and four times the work counts no more than about eight times as many cycles

  Scenario: clock_ms measures intervals and never goes back
    Given clock_ms read across a 50 ms sleep, and 1000 times in a row
    When the readings are compared
    Then the sleep moved it forward by at least 50, no reading is less than the one before, and now_ms is the wall clock

  Scenario: a match case may be a glob, in any program
    Given a match with the cases *.txt, img* and *fred*, in a program that includes nothing, and glob_match called with * and ? patterns
    When names, a name with a two-byte character and an int are matched
    Then each takes the case its glob describes, ? is one character, and the int matches no glob

  Scenario: host_caps says what the host running the program can do
    Given host_caps() read in a native build and in a browser
    When the lists are compared
    Then the native one is x64, subprocess, tcp and fs, and the browser's is wasm alone

  Scenario: solve follows a search as deep as it needs, and says when it cannot
    Given a chain of 300 next facts with a recursive reach rule, and a rule that leads back to itself
    When reach from n0 to n100 and to n250 is solved, and then the rule that leads back to itself
    Then both reaches have their one answer, and the third stops the program naming the goal, nothing after it running

  Scenario: exec_capture_io feeds a child's input while reading its output
    Given cmd typing a 300 KB file and then echoing its input with findstr, given 300 KB of input
    When exec_capture_io runs it with a 60 second timeout
    Then it succeeds, both outputs are there whole, and it took well under the timeout

  Scenario: not binds more loosely than a comparison and more tightly than and and or
    Given not a == b, not a < b, not a == b and false, not a == 1 or true, and the bracketed forms
    When each is evaluated with a 1 and b 2
    Then not applies to the whole comparison, and and and or to the not

  Scenario: any expression's value can be called
    Given a call's result, a list element and a bracketed closure, each followed by arguments
    When each is called
    Then each gives what its closure returns

  Scenario: errors name what went wrong in the program's terms
    Given a program using an undefined variable on line 6, a program dividing 7 by 0, and an operation given a float, a modint and an interval it does not take
    When each is built and run
    Then the first is refused naming line 6, the second stops with division by zero, and the others name the type the operation does not take

  Scenario: a string that is never closed, and the lines after a string of several lines
    Given a string opened on line 4 and never closed, a string over three lines followed by a stray ) on line 8, and numbers with exponents
    When each is built
    Then the first is refused at line 4 saying the string is never closed, the second names line 8, and 1e3, 2.5e-2 and 4E+1 are numbers

  Scenario: the compiler names each call of a name nothing declares
    Given a program that calls tokenize, which nothing it reaches declares
    When v2 builds it
    Then the build succeeds and warns that tokenize is called and nothing declares it

  Scenario: the compiler warns when a loop body takes the loop's counter for an inner loop
    Given a loop on line 7 whose body sets its counter s, then counts an inner loop with s, and a loop whose inner loops move its index on
    When v2 builds each
    Then the first build warns naming line 7 and s, the second warns of nothing, and both programs run as written

  Scenario: the compiler warns of an index that is certainly not an int or a modint
    Given a program indexing with a float, a sqrt and a string, and passing floor of a float to a function that indexes with it through another, and a program whose indexes are ints, modints, parameters, elements and a name that is not always a float
    When v2 builds each
    Then the first build warns of each, naming its line and the call, the second warns of nothing, and the first runs until its first float index

  Scenario: a program declares whether a string stands for the object of that name
    Given an object named w1, in a program that declares nothing and in one that declares object_names_explicit()
    When each reads it through object_named, reads w1.color or w1.length from the string, and deletes the object given the string
    Then object_named gives the object in both; without the declaration the string reaches the object and deletes it, and with it the string is only a string and deletes nothing

  Scenario: a plan's steps keep their values as bound
    Given an action whose step binds a text holding a comma and an int, and a closure bound to it
    When the plan is made and activated
    Then the step's values are the text whole and the int as an int, its label writes both, and the closure is given exactly those two values

  Scenario: the virtual files' work grows with what each call needs
    Given 8000 and 16000 virtual files written, read, and appended to one file 16 bytes at a time
    When each phase is timed
    Then four times the files or appends take no more than about eight times as long

  Scenario: the interpreter reads the runtime's declarations from a cache
    Given a program the interpreter has run
    When the cache of the runtime's declarations is read
    Then its key names each runtime file with its size and time of writing, and it ends with the count of the functions it holds

  Scenario: a passing contract clause is one contract_holds fact however often it passes
    Given a function with a require and an ensure, called once and then 100000 times
    When contract_holds is solved for it after the first call and after the rest
    Then there are two facts, the require's and the ensure's, both times

  Scenario: solve_up_to gives the first n solutions and stops there
    Given 4000 facts, a rule pairing them, a store of two colours, and rules whose bodies have 200 and 800 goals
    When solve_up_to and solve_up_to_in ask for the first few solutions of each
    Then each gives solve's first solutions in solve's order, none past n, the pair rule's first two of its 16 million, and the 800-goal body in no more than about eight times the 200-goal body's time

  Scenario: following a chain of facts takes time growing as its length
    Given chains of 500 and 1000 next facts and a recursive reach rule
    When reach from the first to the last is solved on each
    Then the four times longer takes no more than about eight times as long

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
    Given a chain of two builds and 10 goals each needing the second, a goal no action reaches, two routes of different cost, and 40 then 160 goals timed
    When plan is asked for each
    Then the builds come first and every goal is met, the unreachable goal gives [], the cheaper route is taken, and four times the goals take no more than about 32 times as long

  Scenario: the logic engine's work grows with what each call needs
    Given 2,000 and then 8,000 rules added, a bound goal solved before and after 20,000 rules of another predicate are added, and goals with 2,000 and 8,000 solutions
    When a program times them
    Then four times the rules take no more than about eight times as long, the other predicate's rules cost the goal little, and four times the solutions take no more than about eight times as long

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

  Scenario: a bare value statement prints its value, wherever it is
    Given a program whose statements are a call whose value nothing uses, a sum, a variable, and last a string and an int
    When it runs
    Then the call's value is not printed, and each bare value is, the last ones included

  Scenario: a call naming a function with the wrong number of arguments is refused
    Given a function taking two arguments, and one taking one and rest, each called with too few or too many, and a closure called with nine
    When the program is compiled
    Then both engines refuse it, naming the function and both numbers, and that a closure takes at most 8, and nothing runs

  Scenario: a condition on vfs_exists takes the branch it says
    Given a virtual file that was never written, and one that was written and then deleted
    When vfs_exists of each is a condition, and is printed
    Then the missing file takes the false branch and the written one the true, and it gives the bools false and true

  Scenario: a program's arguments arrive as they were passed
    Given arguments that are plain, hold a space, end in a backslash after a space, hold a quote after a backslash, are empty, and end in two backslashes
    When a program that prints its argv is run with them
    Then it has eight arguments, each unchanged

  Scenario: a string is a logic constant whatever its first letter
    Given facts, queries, a rule declaration and a plan whose constants begin with capital letters, and variables made by logic_var and by capitalised names in the declaration
    When the program runs
    Then a capitalised constant matches only itself, a variable matches any constant, and a logic variable is a value of its own type, equal to another of the same name and to no string

  Scenario: a let that rebinds a variable to a call taking it is a call like any other
    Given a let rebinding a variable to a call that takes it, of a closure held in a parameter, of a function ending in rest with further arguments, and of the program's own max
    When the program runs
    Then the closure is called, rest holds the further arguments, and the program's max runs, each as through a new name

  Scenario: a let that rebinds a variable to a call with too many arguments is refused
    Given a let rebinding a variable to a call of a function taking one argument, given three
    When the program is compiled
    Then both engines refuse it, naming the function and both numbers, as for any call, and nothing runs

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
