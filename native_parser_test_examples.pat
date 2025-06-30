# Native Parser Test Examples - Specific test cases for validation
# These examples are designed for systematic testing of parsing capabilities

# ==== BASIC EXPRESSIONS TEST CASES ====

# Simple arithmetic
2 + 3
5 - 2
4 * 6
8 / 2
3 ** 2

# Complex arithmetic with precedence
2 + 3 * 4
(2 + 3) * 4
5 + 6 / 2 - 1
a * b + c / d
x ** 2 + y ** 2

# Boolean expressions
true and false
not true
x > 5 and y < 10
(a == b) or (c != d)
age >= 18 and has_license

# String operations
"hello" + " world"
name + " is " + age + " years old"
"Hello, " + user.name

# ==== VARIABLE ASSIGNMENTS TEST CASES ====

# Simple assignments
x = 5
name = "Alice"
active = true

# Let declarations
let counter = 0
let message = "Hello World"
let is_valid = true

# Const declarations
const PI = 3.14159
const MAX_USERS = 1000

# Type-annotated assignments
let user_count: Number = 42
let username: String = "john_doe"
let is_admin: Boolean = false

# Multiple assignments
let a = 1, b = 2, c = 3

# Complex assignments
user.profile.name = "Bob"
scores[0] = 95
data[key].value = result

# Compound assignments
counter += 1
balance -= 50
score *= 2
total /= count

# ==== FUNCTION DEFINITION TEST CASES ====

# Natural language functions
make a function called greet takes name
    print("Hello, " + name)
end

make a function called add takes x, y
    return x + y
end

make a function called calculate takes numbers
    let sum = 0
    for num in numbers do
        sum = sum + num
    end
    return sum
end

# Traditional function syntax
function multiply(a, b) {
    return a * b
}

def square(x)
    x * x
end

# Lambda functions
let double = lambda(x) { x * 2 }
let isEven = lambda(n) n % 2 == 0

# Function with default parameters
make a function called create_user takes name, age = 25, role = "user"
    return {name: name, age: age, role: role}
end

# ==== CONTROL FLOW TEST CASES ====

# Simple if statements
if x > 0 then
    print("positive")
end

if temperature > 30 then
    print("hot")
else
    print("not hot")
end

# If-elsif-else
if score >= 90 then
    grade = "A"
elsif score >= 80 then
    grade = "B"
elsif score >= 70 then
    grade = "C"
else
    grade = "F"
end

# Unless statement
unless user.authenticated then
    redirect_to_login()
end

# While loops
while count < 10 do
    count = count + 1
end

# For-in loops
for item in shopping_list do
    print(item)
end

for i in 1..10 do
    print(i)
end

# Until loops
until finished do
    task = get_next_task()
    if task == null then
        finished = true
    end
end

# Case statements
case user.role
when "admin" then
    show_admin_panel()
when "user" then
    show_user_dashboard()
else
    show_guest_content()
end

# Loop control
for i in 1..100 do
    if i % 2 == 0 then
        continue
    end
    if i > 50 then
        break
    end
    print(i)
end

# ==== REASONING CONSTRUCTS TEST CASES ====

# Basic facts
fact parent(john, mary)
fact parent(mary, alice)
fact age(john, 45)
fact age(mary, 20)

# Simple rules
rule grandparent(X, Z) :-
    parent(X, Y),
    parent(Y, Z)

rule adult(Person) :-
    age(Person, Age),
    Age >= 18

# Complex rules with constraints
rule can_vote(Person) :-
    adult(Person),
    citizen(Person),
    not criminal_record(Person)

rule sibling(X, Y) :-
    parent(P, X),
    parent(P, Y),
    X \= Y

# Goals with preconditions
goal find_ancestors(person) {
    precondition: person != null,
    postcondition: result != [],
    strategy: backward_chaining
}

goal validate_user(user) {
    precondition: user.email != null,
    postcondition: result.valid == true or result.errors != [],
    strategy: constraint_satisfaction
}

# Constraints
constrain age(X, Y) and Y >= 0 and Y =< 150
constrain parent(X, Y) and X != Y
domain voting_age in 18..120

# Queries
query parent(john, X)
ask grandparent(bob, alice)
find Person where adult(Person)

# ==== EXCEPTION HANDLING TEST CASES ====

# Simple try-catch
try
    result = risky_operation()
catch error
    handle_error(error)
end

# Multiple catch clauses
try
    data = fetch_data()
    process_data(data)
catch network_error
    retry_connection()
catch data_error
    use_default_data()
finally
    cleanup()
end

# Throw statements
if invalid_input then
    throw new ValidationError("Invalid input")
end

# ==== OBJECT-ORIENTED TEST CASES ====

# Class definition
class User
    def initialize(name, email)
        @name = name
        @email = email
    end
    
    def greeting
        return "Hello, I'm " + @name
    end
    
    def is_admin?
        return @role == "admin"
    end
end

# Object creation and method calls
user = User.new("Alice", "alice@example.com")
message = user.greeting()

# Method chaining
result = data
    .filter(lambda(x) { x > 0 })
    .map(lambda(x) { x * 2 })
    .sum()

# ==== MIXED PARADIGM TEST CASES ====

# Combining functions with reasoning
make a function called get_permissions takes user_id
    let permissions = []
    query has_permission(user_id, Permission)
    for permission in query_results do
        permissions.push(permission)
    end
    return permissions
end

# Constraint-based algorithms
make a function called solve_puzzle takes constraints
    constrain valid_solution(solution, constraints)
    solution = find_solution()
    return solution
end

# ==== ERROR RECOVERY TEST CASES ====

# Missing end keyword
if true then
    print("test")
# Missing end - should recover

# Incomplete function
make a function called incomplete
# Missing body - should recover

# Invalid assignment
let x = 
# Missing value - should recover

# Unmatched parentheses
result = calculate(1, 2, (3 + 4
# Missing ) - should recover

# Malformed rule
rule invalid_rule :-
# Missing body - should recover

# ==== PERFORMANCE TEST CASES ====

# Large function with many statements
make a function called large_function takes data
    let result = {}
    let counter = 0
    
    for item in data do
        if item.valid then
            processed = transform(item)
            if processed.score > 50 then
                result[counter] = processed
                counter = counter + 1
            end
        end
    end
    
    for i in 1..100 do
        if i % 10 == 0 then
            result.milestones = result.milestones || []
            result.milestones.push(i)
        end
    end
    
    return result
end

# Deeply nested structures
if condition1 then
    if condition2 then
        if condition3 then
            if condition4 then
                if condition5 then
                    perform_action()
                end
            end
        end
    end
end

# Complex expressions
result = (a + b * c - d / e) ** 2 + (f * g + h - i) / (j + k * l)

# Large data structure
let config = {
    database: {
        host: "localhost",
        port: 5432,
        credentials: {
            username: "admin",
            password: "secret"
        }
    },
    cache: {
        enabled: true,
        ttl: 3600,
        backends: ["redis", "memcached"]
    },
    logging: {
        level: "info",
        outputs: ["console", "file"],
        format: "json"
    }
}

# ==== INTEGRATION TEST CASES ====

# Complete program combining multiple features
make a function called comprehensive_test takes input
    # Variable setup
    let results = []
    const THRESHOLD = 100
    
    # Exception handling
    try
        # Control flow
        if input != null and input.length > 0 then
            for item in input do
                # Reasoning integration
                if query valid_item(item) then
                    # Function calls
                    processed = process_item(item)
                    
                    # Complex conditions
                    if processed.score > THRESHOLD and not processed.duplicate then
                        results.push(processed)
                    end
                else
                    log_invalid(item)
                end
            end
        end
        
        # Higher-order functions
        final_results = results
            .filter(lambda(x) { x.approved })
            .sort_by(lambda(x) { x.priority })
        
        return final_results
        
    catch processing_error
        handle_error(processing_error)
        return []
    end
end

# Natural language with reasoning
make a function called intelligent_search takes query, dataset
    # Define search constraints
    constrain relevant(item, query) :- similarity(item, query) > 0.8
    constrain not duplicate(item, results)
    
    # Goal-driven search
    goal find_best_matches(query, dataset) {
        precondition: query != "" and dataset != [],
        postcondition: result.count <= 10 and all_relevant(result, query),
        strategy: constraint_satisfaction
    }
    
    # Execute search
    matches = solve find_best_matches(query, dataset)
    
    return matches
end