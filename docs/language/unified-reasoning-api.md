# Unified Reasoning API Specification

## Overview

This document specifies the programming interfaces for Patlang's unified reasoning systems, encompassing **Type Inference**, **Goal-Oriented Programming**, and **Logic Programming**. The API design prioritizes seamless integration with existing object-oriented and event-driven patterns while providing powerful declarative programming capabilities.

## Type Inference API

### Type Constraint Declaration

#### Basic Type Constraints

```patlang
# Variable type constraints
constrain x :: Number
constrain name :: String
constrain valid :: Boolean

# Parametric type constraints
constrain items :: List(Number)
constrain mapping :: Map(String, Number)
constrain optional :: Maybe(String)
```

#### Advanced Type Constraints

```patlang
# Range constraints
constrain age :: Number where age >= 0 and age <= 150

# Pattern constraints
constrain email :: String where email matches /\w+@\w+\.\w+/

# Structural constraints
constrain person :: Object {
  name :: String,
  age :: Number,
  email :: String
}

# Dependent type constraints
constrain matrix :: Array(Array(Number)) where 
  all rows have same length and
  length > 0
```

#### Type Constraint Events

```patlang
# Subscribe to type inference events
on type_refined(variable, old_type, new_type) do
  print "Type of #{variable} refined from #{old_type} to #{new_type}"
end

on constraint_violated(variable, constraint, value) do
  error "Constraint violation: #{variable} = #{value} violates #{constraint}"
end

on unification_failed(term1, term2, reason) do
  debug "Cannot unify #{term1} with #{term2}: #{reason}"
end
```

### Type Inference Functions

#### Manual Type Operations

```patlang
# Explicit type checking
if x is Number then
  print "x is a number"
end

# Type conversion with validation
y = x as String  # Throws if conversion impossible
z = x to String  # Returns Maybe(String)

# Type introspection
type_of(x)           # Returns current inferred type
constraints_of(x)    # Returns active constraints
type_history(x)      # Returns type refinement history
```

#### Type Unification

```patlang
# Manual unification
result = unify(term1, term2)
if result.success then
  print "Unified with substitution: #{result.substitution}"
else
  print "Unification failed: #{result.reason}"
end

# Unification with context
result = unify(term1, term2, context: current_scope)
```

## Goal-Oriented Programming API

### Goal Definition

#### Basic Goal Declaration

```patlang
# Simple goals
goal find_maximum(list) {
  precondition: list is not empty
  postcondition: result >= all elements in list
}

goal sort_list(input_list) {
  precondition: input_list is List
  postcondition: result is sorted and contains same elements as input_list
}
```

#### Complex Goal Structures

```patlang
# Hierarchical goals
goal process_order(order) {
  precondition: order.status == "pending"
  postcondition: order.status == "completed"
  
  subgoals: [
    validate_payment(order.payment),
    reserve_inventory(order.items),
    ship_order(order)
  ]
  
  failure_handler: rollback_order(order)
}

# Conditional goals
goal optimize_route(start, end, criteria) {
  precondition: start and end are valid locations
  postcondition: result.distance <= shortest_possible_distance
  
  strategy: match criteria {
    "fastest" => minimize_time(start, end)
    "shortest" => minimize_distance(start, end)
    "cheapest" => minimize_cost(start, end)
  }
}
```

### Goal Pursuit

#### Goal Execution

```patlang
# Basic goal pursuit
result = pursue find_maximum([3, 1, 4, 1, 5])
print result.value  # 5

# Goal pursuit with options
result = pursue sort_list([3, 1, 4]) with {
  strategy: "quicksort",
  timeout: 5000ms,
  max_backtrack_depth: 10
}

# Asynchronous goal pursuit
future_result = pursue_async process_large_dataset(data)
# ... other work ...
result = await future_result
```

#### Goal Events and Monitoring

```patlang
# Goal lifecycle events
on goal_started(goal) do
  print "Started pursuing goal: #{goal.description}"
end

on goal_completed(goal, result) do
  print "Goal completed: #{goal.description} -> #{result}"
end

on goal_failed(goal, reason) do
  print "Goal failed: #{goal.description}, reason: #{reason}"
end

on subgoal_created(parent_goal, subgoal) do
  print "Created subgoal #{subgoal} for #{parent_goal}"
end

# Goal stack monitoring
on goal_stack_depth_changed(new_depth) do
  if new_depth > 10 then
    warn "Deep goal recursion detected: depth #{new_depth}"
  end
end
```

### Goal Strategies and Backtracking

#### Strategy Definition

```patlang
# Custom goal resolution strategies
strategy bruteforce_search(goal, context) {
  for solution in all_possible_solutions(goal) do
    if solution satisfies goal.postcondition then
      return solution
    end
  end
  fail "No solution found"
}

strategy heuristic_search(goal, context) {
  candidates = generate_candidates(goal)
  sorted_candidates = sort_by_heuristic(candidates, goal)
  
  for candidate in sorted_candidates do
    if try_solution(candidate, goal) then
      return candidate
    end
  end
  fail "No solution found"
}

# Assign strategy to goal
goal solve_puzzle(puzzle) {
  strategy: heuristic_search
  postcondition: puzzle.is_solved()
}
```

#### Backtracking Control

```patlang
# Manual backtracking
goal find_path(start, end, visited = []) {
  if start == end then
    return [end]
  end
  
  for neighbor in neighbors(start) - visited do
    choice_point {
      path = pursue find_path(neighbor, end, visited + [start])
      return [start] + path
    } backtrack_on_failure
  end
  
  fail "No path found"
}

# Backtracking with cut
goal find_first_solution(problem) {
  for approach in solution_approaches do
    choice_point {
      solution = try_approach(approach, problem)
      cut  # Don't try other approaches
      return solution
    } backtrack_on_failure
  end
}
```

## Logic Programming API

### Facts and Rules

#### Fact Declaration

```patlang
# Basic facts
fact parent(john, mary)
fact parent(mary, susan)
fact parent(bob, john)

# Typed facts
fact age(Person, Number)
fact age(john, 45)
fact age(mary, 20)

# Complex facts with objects
fact employee(Person, Department, Salary) where
  Person is String,
  Department is String,
  Salary is Number and Salary > 0

fact employee("Alice", "Engineering", 75000)
fact employee("Bob", "Sales", 65000)
```

#### Rule Definition

```patlang
# Basic rules
rule grandparent(X, Z) if parent(X, Y) and parent(Y, Z)

# Rules with conditions
rule senior_employee(Person) if 
  employee(Person, _, Salary) and
  Salary > 70000

rule can_afford(Person, Item) if
  salary(Person, S) and
  price(Item, P) and
  S > P * 2

# Rules with type constraints
rule eligible_for_promotion(Employee :: String) if
  employee(Employee, Department, Salary) and
  years_experience(Employee, Years) and
  Years >= 2 and
  performance_rating(Employee, Rating) and
  Rating >= 4.0
```

#### Recursive Rules

```patlang
# Ancestor relationship
rule ancestor(X, Y) if parent(X, Y)
rule ancestor(X, Z) if parent(X, Y) and ancestor(Y, Z)

# Transitive closure
rule connected(X, Y) if edge(X, Y)
rule connected(X, Z) if edge(X, Y) and connected(Y, Z)

# List operations
rule length([], 0)
rule length([_|Tail], N) if length(Tail, M) and N = M + 1

rule append([], L, L)
rule append([H|T], L, [H|R]) if append(T, L, R)
```

### Queries

#### Basic Queries

```patlang
# Simple queries
?- parent(john, mary)          # Returns: true
?- parent(mary, X)             # Returns: X = susan
?- parent(X, Y)                # Returns all parent relationships

# Queries with variables
?- grandparent(bob, X)         # Find grandchildren of bob
?- ancestor(X, susan)          # Find ancestors of susan
```

#### Complex Queries

```patlang
# Multiple constraints
?- employee(Person, "Engineering", Salary) and Salary > 70000

# Queries with calculations
?- employee(Person, Dept, Salary) and 
   tax_rate(Dept, Rate) and 
   NetSalary = Salary * (1 - Rate)

# Existential queries
?- exists Person: employee(Person, "Engineering", _)

# Universal queries
?- forall Person: (employee(Person, _, Salary) implies Salary > 30000)
```

#### Query Results and Iteration

```patlang
# Collect all solutions
solutions = query ?- parent(X, Y)
for solution in solutions do
  print "#{solution.X} is parent of #{solution.Y}"
end

# Query with limits
first_five = query ?- employee(Person, Dept, Salary) limit 5

# Query with ordering
sorted_employees = query ?- employee(Person, Dept, Salary) 
                     order by Salary desc

# Lazy query evaluation
results = lazy_query ?- big_computation(X, Y)
for result in results.take(10) do
  print result
end
```

### Knowledge Base Management

#### Dynamic Facts

```patlang
# Assert new facts at runtime
assert_fact(employee("Charlie", "Marketing", 60000))

# Retract facts
retract_fact(employee("Bob", "Sales", 65000))

# Update facts (retract old, assert new)
update_fact(
  old: employee("Alice", "Engineering", 75000),
  new: employee("Alice", "Engineering", 80000)
)

# Conditional assertion
if not exists ?- department("Research") then
  assert_fact(department("Research"))
end
```

#### Rule Management

```patlang
# Add rules dynamically
add_rule(
  rule high_performer(Person) if
    performance_rating(Person, Rating) and
    Rating >= 4.5
)

# Remove rules
remove_rule("high_performer/1")

# List all rules
for rule in all_rules() do
  print rule.signature
end
```

## Cross-Paradigm Integration

### Type-Guided Goal Resolution

```patlang
# Goals that use type constraints
goal find_valid_input(validator_function) {
  precondition: validator_function :: Function(Any -> Boolean)
  postcondition: validator_function(result) == true
  
  strategy: {
    # Use type system to generate candidates
    candidates = generate_typed_values(input_type_of(validator_function))
    for candidate in candidates do
      if validator_function(candidate) then
        return candidate
      end
    end
  }
}

# Type refinement through goal achievement
goal parse_number(text :: String) {
  postcondition: result :: Number
  
  # Goal achievement refines the result type
  strategy: {
    try {
      return Float.parse(text)
    } catch {
      return Integer.parse(text)
    }
  }
}
```

### Logic-Enhanced Type Checking

```patlang
# Use logic rules for type validation
rule valid_email(Email :: String) if
  Email matches /\w+@\w+\.\w+/ and
  not_in_blacklist(Email)

rule valid_user(User :: Object) if
  User.name :: String and
  valid_email(User.email) and
  User.age :: Number and
  User.age >= 13

# Apply logic rules in type constraints
constrain user :: Object where valid_user(user)
```

### Event-Driven Reasoning

```patlang
# React to reasoning events across paradigms
on type_refined(variable, old_type, new_type) do
  # Update relevant goals
  goals_affected = find_goals_using_variable(variable)
  for goal in goals_affected do
    reconsider_goal(goal)
  end
  
  # Update logic facts
  if variable == "user_age" and new_type == Number then
    assert_fact(user_age_is_number(variable))
  end
end

on fact_asserted(predicate, args) do
  # Update type constraints based on facts
  if predicate == "typeof" then
    constrain args[0] :: args[1]
  end
  
  # Trigger goal reconsideration
  affected_goals = find_goals_mentioning(predicate)
  for goal in affected_goals do
    reconsider_goal(goal)
  end
end

on goal_completed(goal, result) do
  # Extract type information from successful goals
  if goal.postcondition mentions result.type then
    constrain goal.result :: result.type
  end
  
  # Assert derived facts
  if goal.name == "validate_user" and result == true then
    assert_fact(valid_user(goal.arguments[0]))
  end
end
```

## API Usage Examples

### Complete Integration Example

```patlang
# Define types for a user management system
constrain User :: Object {
  id :: Number,
  name :: String,
  email :: String,
  age :: Number where age >= 13
}

# Define logic rules for validation
rule valid_email(Email) if
  Email matches /^[^\s@]+@[^\s@]+\.[^\s@]+$/

rule can_register(User) if
  valid_email(User.email) and
  User.age >= 13 and
  not_exists ?- registered_user(User.email)

# Define goal for user registration
goal register_user(user_data) {
  precondition: user_data :: Object
  postcondition: result :: User and can_register(result)
  
  strategy: {
    # Type system validates structure
    validated_user = user_data as User
    
    # Logic system checks business rules
    if query ?- can_register(validated_user) then
      # Register and return
      assert_fact(registered_user(validated_user.email))
      return validated_user
    else
      fail "User cannot be registered"
    end
  }
}

# Usage
user_input = {
  id: 123,
  name: "John Doe", 
  email: "john@example.com",
  age: 25
}

result = pursue register_user(user_input)
print "Registered user: #{result}"
```

### Error Handling and Debugging

```patlang
# Comprehensive error handling
try {
  constrain problematic_var :: ComplexType
  result = pursue complex_goal(problematic_var)
  assert_fact(derived_from_goal(result))
} catch TypeConstraintViolation(var, constraint, value) {
  print "Type error: #{var} = #{value} violates #{constraint}"
} catch GoalFailure(goal, reason) {
  print "Goal failed: #{goal} because #{reason}"
} catch UnificationFailure(term1, term2, reason) {
  print "Cannot unify #{term1} and #{term2}: #{reason}"
} catch FactAssertionError(fact, reason) {
  print "Cannot assert fact #{fact}: #{reason}"
}

# Debugging support
debug {
  trace_type_inference(on)
  trace_goal_resolution(on)
  trace_logic_queries(on)
  
  # Run problematic code
  result = complex_reasoning_operation()
  
  # Examine reasoning trace
  print type_inference_trace()
  print goal_resolution_trace()
  print logic_query_trace()
}
```

## Performance Tuning API

### Caching Control

```patlang
# Control reasoning caches
cache_policy {
  type_inference: LRU(size: 1000, ttl: 300s)
  goal_resolution: LRU(size: 500, ttl: 600s)
  logic_queries: LRU(size: 2000, ttl: 120s)
}

# Manual cache operations
clear_type_cache()
clear_goal_cache()
clear_query_cache()

# Cache statistics
stats = reasoning_cache_stats()
print "Type cache hit rate: #{stats.type_cache.hit_rate}"
```

### Resource Limits

```patlang
# Set reasoning limits
reasoning_limits {
  max_goal_stack_depth: 50
  max_unification_steps: 10000
  max_query_results: 1000
  timeout: 30s
}

# Per-operation limits
result = pursue complex_goal(data) with {
  timeout: 10s,
  max_backtrack_depth: 20
}
```

## API Extensibility

### Custom Reasoning Components

```patlang
# Define custom type checker
define_type_checker(EmailType) {
  validate: λ(value) -> value matches /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  convert_from: [String]
  convert_to: [String]
}

# Define custom goal strategy
define_goal_strategy(genetic_algorithm) {
  setup: λ(goal, context) -> initialize_population(goal)
  step: λ(population, goal) -> evolve_population(population, goal)
  check: λ(individual, goal) -> evaluate_fitness(individual, goal)
  complete: λ(population, goal) -> best_individual(population)
}

# Define custom logic predicate
define_predicate(distance) {
  arity: 3  # distance(Point1, Point2, Distance)
  implementation: λ(p1, p2, d) -> 
    calculate_euclidean_distance(p1, p2) == d
}
```

This API specification provides a comprehensive interface for working with Patlang's unified reasoning systems while maintaining compatibility with the existing object-oriented foundation and event-driven architecture.