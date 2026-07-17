# Native Parser Demo - Comprehensive examples showcasing all parser capabilities
# Complete demonstration of Phase 2 advanced parser implementation
# Examples for native vs Ruby parser comparison and performance testing

# ==== NATURAL LANGUAGE FUNCTION SYNTAX EXAMPLES ====

# Basic natural language function
make a function called greet takes name
    print("Hello, " + name + "!")
end

# Function with return value
make a function called add takes x, y returns x + y end

# Function with complex parameters and body
make a function called calculate_statistics takes numbers
    let sum = 0
    let count = 0
    
    for num in numbers do
        sum = sum + num
        count = count + 1
    end
    
    let average = sum / count
    return {sum: sum, count: count, average: average}
end

# Function with optional parameters
make a function called create_user takes name, age = 25, role = "user"
    return {
        name: name,
        age: age,
        role: role,
        created_at: current_time()
    }
end

# ==== TRADITIONAL FUNCTION SYNTAX EXAMPLES ====

# Traditional function syntax
function multiply(a, b) {
    return a * b
}

# Short form function
def square(x)
    x * x
end

# Lambda function
let double = lambda(x) { x * 2 }

# Lambda with expression body
let triple = lambda(x) x * 3

# Proc function
let logger = proc { |message| puts("[LOG] " + message) }

# ==== ADVANCED VARIABLE DECLARATIONS ====

# Let declarations
let counter = 0
let name = "Alice"
let is_active = true

# Const declarations
const PI = 3.14159
const MAX_USERS = 1000

# Variable declarations with type annotations
let user_count: Number = 42
let username: String = "john_doe"
let is_admin: Boolean = false

# Multiple variable declarations
let a = 1, b = 2, c = 3
const X = 10, Y = 20, Z = 30

# ==== COMPLEX ASSIGNMENT STATEMENTS ====

# Simple assignments
x = 42
name = "Bob"

# Member access assignments
user.name = "Charlie"
config.database.host = "localhost"

# Array index assignments
scores[0] = 95
matrix[i][j] = value

# Compound assignments
counter += 1
balance -= withdrawal_amount
score *= multiplier
total /= count

# Complex assignment patterns
user.profile.settings.theme = "dark"
cache[key].data[index] = new_value

# ==== COMPREHENSIVE CONTROL FLOW EXAMPLES ====

# If-elsif-else statements
if temperature > 30 then
    print("It's hot!")
elsif temperature > 20 then
    print("It's warm")
elsif temperature > 10 then
    print("It's cool")
else
    print("It's cold!")
end

# Unless statement
unless user.is_authenticated then
    redirect_to_login()
end

# Complex conditions
if (age >= 18 and has_license) or is_emergency then
    allow_driving()
else
    deny_driving()
end

# Nested conditionals
if user != null then
    if user.is_active then
        if user.has_permission("read") then
            show_content()
        else
            show_access_denied()
        end
    else
        show_account_suspended()
    end
else
    show_login_required()
end

# While loops
while not finished do
    work_item = get_next_work_item()
    process(work_item)
    if work_item.is_last then
        finished = true
    end
end

# For-in loops
for item in shopping_list do
    print("Need to buy: " + item)
end

for user in active_users do
    send_notification(user, "Welcome back!")
end

# Until loops
until queue.is_empty do
    task = queue.pop()
    execute_task(task)
end

# Loop with break and continue
for i in 1..100 do
    if i % 2 == 0 then
        continue  # Skip even numbers
    end
    
    if i > 50 then
        break  # Stop after 50
    end
    
    print("Odd number: " + i)
end

# Infinite loop with conditions
loop do
    input = get_user_input()
    
    if input == "quit" then
        break
    end
    
    process_input(input)
end

# Case statement
case user.role
when "admin" then
    show_admin_panel()
when "moderator" then
    show_moderator_tools()
when "user" then
    show_user_dashboard()
else
    show_guest_content()
end

# ==== ADVANCED REASONING CONSTRUCTS ====

# Basic facts
fact parent(john, mary)
fact parent(mary, alice)
fact parent(bob, john)
fact age(john, 45)
fact age(mary, 20)
fact age(alice, 2)

# Rules with complex bodies
rule grandparent(X, Z) :-
    parent(X, Y),
    parent(Y, Z)

rule adult(X) :-
    age(X, Age),
    Age >= 18

rule can_vote(X) :-
    adult(X),
    citizen(X),
    not criminal_record(X)

# Goals with preconditions and postconditions
goal find_grandparents(person) {
    precondition: person != null and exists(parent(person, _)),
    postcondition: result.count >= 0 and all_valid_grandparents(result),
    strategy: backward_chaining
}

goal validate_voting_eligibility(citizen) {
    precondition: citizen.age != null and citizen.citizenship_status != null,
    postcondition: result.eligible == true or result.reasons != [],
    strategy: constraint_satisfaction
}

# Constraints
constrain age(X, Y) and Y >= 0 and Y =< 150
constrain parent(X, Y) and X != Y
domain voting_age in 18..120

# Queries
query parent(john, X)
ask grandparent(bob, alice)
find X where adult(X) and parent(X, _)

# Complex reasoning with unification
rule sibling(X, Y) :-
    parent(P, X),
    parent(P, Y),
    X \= Y

rule ancestor(X, Y) :-
    parent(X, Y)

rule ancestor(X, Y) :-
    parent(X, Z),
    ancestor(Z, Y)

# ==== EXCEPTION HANDLING EXAMPLES ====

# Try-catch statements
try
    result = risky_operation()
    process_result(result)
catch error
    log_error(error)
    handle_error(error)
end

# Try-catch with multiple catch clauses
try
    data = fetch_data_from_api()
    validate_data(data)
    store_data(data)
catch network_error
    retry_with_backoff()
catch validation_error
    log_validation_failure(validation_error)
    use_default_data()
catch storage_error
    alert_administrators(storage_error)
    use_temporary_storage()
finally
    cleanup_resources()
end

# Throw statements
if invalid_input then
    throw new ValidationError("Input must be positive number")
end

# ==== COMPLEX EXPRESSION EXAMPLES ====

# Arithmetic expressions
result = (a + b) * (c - d) / (e + f)
compound = x ** 2 + y ** 2 - 2 * x * y * cos(angle)

# Logical expressions
is_valid = (age >= 18) and (has_id or has_passport) and not banned
complex_condition = (x > 0 and y > 0) or (x < 0 and y < 0) or (x == 0 and y == 0)

# Function calls with various argument types
result = process_data(
    data: raw_data,
    options: {
        validate: true,
        transform: "uppercase",
        cache: false
    },
    callback: lambda(processed) { save_to_database(processed) }
)

# Method chaining
final_result = initial_data
    .filter(lambda(item) { item.is_active })
    .map(lambda(item) { transform_item(item) })
    .sort_by(lambda(item) { item.priority })
    .take(10)

# ==== OBJECT-ORIENTED CONSTRUCTS ====

# Class definition (if supported)
class User
    def initialize(name, email)
        @name = name
        @email = email
        @created_at = current_time()
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

if user.is_admin? then
    grant_admin_access(user)
end

# ==== ADVANCED FUNCTION FEATURES ====

# Function with block parameter
def each_with_index(array, &block)
    for i in 0..(array.length - 1) do
        block.call(array[i], i)
    end
end

# Function call with block
each_with_index(["a", "b", "c"]) { |item, index|
    print("Item " + index + ": " + item)
}

# Higher-order functions
def apply_operation(numbers, operation)
    result = []
    for num in numbers do
        result.push(operation.call(num))
    end
    return result
end

squared_numbers = apply_operation([1, 2, 3, 4, 5], lambda(x) { x * x })

# Recursive functions
make a function called factorial takes n
    if n <= 1 then
        return 1
    else
        return n * factorial(n - 1)
    end
end

make a function called fibonacci takes n
    if n <= 1 then
        return n
    else
        return fibonacci(n - 1) + fibonacci(n - 2)
    end
end

# ==== MIXED PARADIGM EXAMPLES ====

# Combining functional and logic programming
def find_all_ancestors(person, &callback)
    query ancestor(person, X)
    for ancestor in query_results do
        callback.call(ancestor)
    end
end

# Using reasoning in procedural code
make a function called get_user_permissions takes user_id
    let permissions = []
    
    # Use logic programming to determine permissions
    query has_permission(user_id, Permission)
    for permission in query_results do
        permissions.push(permission)
    end
    
    # Apply business rules
    if permissions.include?("admin") then
        permissions = get_all_permissions()
    end
    
    return permissions
end

# Constraint satisfaction in algorithms
make a function called schedule_meetings takes meetings, rooms, time_slots
    # Define constraints
    constrain each_meeting_has_one_room(meetings, rooms)
    constrain no_double_booking(rooms, time_slots)
    constrain meeting_duration_constraints(meetings, time_slots)
    
    # Solve constraints
    solution = solve_constraints()
    
    return solution
end

# ==== PERFORMANCE TESTING EXAMPLES ====

# Large data processing
make a function called process_large_dataset takes data
    let processed_count = 0
    let start_time = current_time()
    
    for item in data do
        # Complex processing logic
        if item.requires_validation then
            validate_item(item)
        end
        
        transformed_item = transform_item(item)
        store_item(transformed_item)
        
        processed_count += 1
        
        if processed_count % 1000 == 0 then
            let elapsed = current_time() - start_time
            print("Processed " + processed_count + " items in " + elapsed + "ms")
        end
    end
    
    return processed_count
end

# Memory-intensive operations
make a function called create_large_structure takes size
    let structure = {}
    
    for i in 1..size do
        structure[i] = {
            id: i,
            data: generate_random_data(100),
            children: create_child_structure(i % 10)
        }
    end
    
    return structure
end

# Recursive performance test
make a function called deep_recursion_test takes depth
    if depth <= 0 then
        return "base case"
    else
        let intermediate = deep_recursion_test(depth - 1)
        return "level " + depth + " -> " + intermediate
    end
end

# ==== ERROR RECOVERY EXAMPLES ====

# Intentionally malformed syntax for testing error recovery
# These examples test the parser's ability to recover from errors

# Missing end keyword (should be recovered)
if true then
    print("test")
# Missing 'end' - parser should recover

# Incomplete function definition
make a function called incomplete
    # Missing parameters and body - parser should recover
    
# Invalid assignment
let x = 
# Missing value - parser should recover

# Unmatched parentheses
result = calculate(1, 2, (3 + 4
# Missing closing paren - parser should recover

# ==== INTEGRATION TEST EXAMPLES ====

# Complete program combining all features
make a function called comprehensive_example takes input_data
    # Variable declarations
    let results = []
    const THRESHOLD = 100
    
    # Control flow with complex conditions
    if input_data != null and input_data.length > 0 then
        # Loop with nested control structures
        for item in input_data do
            # Exception handling
            try
                # Reasoning integration
                if query valid_item(item) then
                    # Function calls and assignments
                    processed_item = process_item(item)
                    
                    # Complex expressions
                    if processed_item.score > THRESHOLD and not processed_item.is_duplicate then
                        results.push(processed_item)
                    end
                else
                    log_invalid_item(item)
                end
            catch processing_error
                handle_processing_error(processing_error, item)
            end
        end
        
        # Higher-order function usage
        final_results = results
            .filter(lambda(item) { item.is_approved })
            .sort_by(lambda(item) { item.priority })
        
        return final_results
    else
        throw new InvalidInputError("Input data is required")
    end
end

# ==== NATIVE PARSER CAPABILITIES SHOWCASE ====

print("🚀 Native Parser Demo - Showcasing Advanced Capabilities")
print("=" * 60)

# Demonstrate natural language syntax
greeting_func = make a function called say_hello takes name, greeting = "Hello"
    return greeting + ", " + name + "!"
end

# Demonstrate complex control flow
make a function called categorize_number takes num
    case true
    when num > 1000 then
        return "large"
    when num > 100 then
        return "medium"  
    when num > 10 then
        return "small"
    when num > 0 then
        return "tiny"
    else
        return "zero or negative"
    end
end

# Demonstrate reasoning integration
fact number_category(X, "large") :- X > 1000
fact number_category(X, "medium") :- X > 100, X =< 1000
fact number_category(X, "small") :- X > 10, X =< 100

query number_category(500, Category)

# Demonstrate all parser components working together
let test_numbers = [5, 50, 500, 5000]

for number in test_numbers do
    # Function call
    func_result = categorize_number(number)
    
    # Reasoning query
    query number_category(number, logic_result)
    
    # Complex conditional
    if func_result == logic_result then
        print("✅ Consistent result for " + number + ": " + func_result)
    else
        print("❌ Inconsistent results for " + number)
        print("  Function: " + func_result)
        print("  Logic: " + logic_result)
    end
end

print("=" * 60)
print("🎯 Native Parser Demo Complete - All Features Demonstrated")

# This file serves as:
# 1. Comprehensive feature demonstration
# 2. Native vs Ruby parser comparison baseline
# 3. Performance testing input
# 4. Integration testing examples
# 5. Documentation of supported syntax