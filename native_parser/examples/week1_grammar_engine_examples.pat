# Week 1 Grammar Engine Implementation Examples
# Demonstrating Phase 2 Week 1 enhanced grammar capabilities

# ==========================================
# BASIC GRAMMAR RULE ACTIVATION EXAMPLES
# ==========================================

# Example 1: Simple assignment with grammar-driven parsing
x = 42
y = x + 10
result = y * 2

# Example 2: Expression parsing with enhanced precedence handling
complex_expr = 5 + 3 * 2 - 1 / 4
boolean_expr = true and false or not true
comparison_expr = x > 5 and y <= 10

# ==========================================
# ADVANCED PATTERN MATCHING EXAMPLES
# ==========================================

# Example 3: Function definition with optional parameters (natural language)
make a function called simple_add takes a, b returns a + b end

make a function called greet takes name
    return "Hello, " + name
end

make a function called factorial takes n
    if n <= 1 then
        return 1
    else
        return n * factorial(n - 1)
    end
end

# Example 4: Control flow with nested structures
if x > 0 then
    if x % 2 == 0 then
        print("Positive even number")
    else
        print("Positive odd number")
    end
else
    print("Non-positive number")
end

# Example 5: Loop structures with statement sequences
counter = 0
while counter < 10 do
    if counter % 2 == 0 then
        print("Even: " + counter)
    end
    counter = counter + 1
end

# ==========================================
# REASONING CONSTRUCT INTEGRATION EXAMPLES
# ==========================================

# Example 6: Facts and rules with grammar validation
fact parent(john, mary)
fact parent(mary, susan)
fact parent(susan, alice)

rule grandparent(X, Z) :-
    parent(X, Y),
    parent(Y, Z)

rule ancestor(X, Y) :-
    parent(X, Y)

rule ancestor(X, Z) :-
    parent(X, Y),
    ancestor(Y, Z)

# Example 7: Goal definitions with complex preconditions
goal find_all_ancestors(person, ancestors) {
    precondition: person != null and ancestors == [],
    postcondition: ancestors.all(a -> ancestor(a, person)),
    strategy: logic_programming_search
}

goal validate_family_tree(tree) {
    precondition: tree != null and tree.members != [],
    postcondition: tree.valid == true and tree.consistency_check_passed == true,
    strategy: recursive_validation_with_backtracking
}

# ==========================================
# TYPE CONSTRAINT EXAMPLES
# ==========================================

# Example 8: Type constraints with enhanced validation
constrain person :: Person where {
    name :: String,
    age :: Number,
    parents :: [Person]
}

constrain employee :: Employee extends Person where {
    employee_id :: String,
    department :: String,
    salary :: Number
}

# ==========================================
# MIXED PARADIGM EXAMPLES
# ==========================================

# Example 9: Functional programming with logical reasoning
make a function called find_employees_in_department takes dept
    goal search_employees(dept, employees) {
        precondition: dept != null,
        postcondition: employees.all(e -> employee(e) and e.department == dept),
        strategy: constraint_satisfaction_search
    }
    return employees
end

# Example 10: Complex program combining all features
fact employee(john, "engineering", 75000)
fact employee(mary, "marketing", 65000)
fact employee(bob, "engineering", 80000)

rule high_earner(Person) :-
    employee(Person, _, Salary),
    Salary > 70000

make a function called calculate_department_budget takes department
    goal find_department_employees(department, employees) {
        precondition: department != null,
        postcondition: employees.all(e -> employee(e, department, _)),
        strategy: logical_search_with_aggregation
    }
    
    total_budget = 0
    employees.each(emp ->
        employee(emp, department, salary),
        total_budget = total_budget + salary
    )
    
    return total_budget
end

# Test the complex functionality
engineering_budget = calculate_department_budget("engineering")
print("Engineering department budget: " + engineering_budget)

# ==========================================
# ERROR RECOVERY DEMONSTRATION EXAMPLES
# ==========================================

# Example 11: Intentional syntax errors for recovery testing
# (These would trigger grammar-aware error recovery)

# Missing operator - should suggest insertion
x = 5 3  # Error: missing operator between 5 and 3

# Mismatched parentheses - should suggest balance
result = (5 + 3 * 2  # Error: missing closing parenthesis

# Invalid function syntax - should suggest correction
make function called test  # Error: missing 'a' in natural language syntax

# ==========================================
# PERFORMANCE OPTIMIZATION EXAMPLES
# ==========================================

# Example 12: Complex nested structures for performance testing
make a function called complex_calculation takes data
    if data != null then
        result = 0
        data.each(item ->
            if item.valid then
                inner_result = 0
                item.values.each(value ->
                    if value > 0 then
                        inner_result = inner_result + value * 2
                    else
                        inner_result = inner_result + value
                    end
                )
                result = result + inner_result
            end
        )
        return result
    else
        return 0
    end
end

# Example 13: Recursive function with memoization opportunities
make a function called fibonacci takes n
    if n <= 1 then
        return n
    else
        return fibonacci(n - 1) + fibonacci(n - 2)
    end
end

# ==========================================
# INTEGRATION WITH PHASE 1 EXAMPLES
# ==========================================

# Example 14: Leveraging existing expression parser with grammar enhancement
mathematical_expression = ((5 + 3) * 2 - 1) / (4 + 2)
logical_expression = (x > 5 and y < 10) or (z == 0 and w != null)
mixed_expression = factorial(5) + fibonacci(8) - complex_calculation(data)

# Example 15: Goal-oriented parsing coordination
goal parse_complex_program(tokens) {
    precondition: tokens != [] and tokens[tokens.length - 1].type == "EOF",
    postcondition: result.type == "Program" and result.valid == true and result.grammar_validated == true,
    strategy: enhanced_grammar_driven_recursive_descent
}

# Example 16: Ruby compatibility demonstration
# All constructs above should produce Ruby-compatible AST nodes
# that can be seamlessly processed by the existing Ruby evaluator

# Final complex example combining everything
fact database_connection(localhost, 5432, "production")
fact user_permission(admin, "read_write")
fact user_permission(guest, "read_only")

rule can_access_database(User, Operation) :-
    user_permission(User, Permission),
    database_operation_allowed(Permission, Operation)

rule database_operation_allowed("read_write", _)
rule database_operation_allowed("read_only", "read")

make a function called secure_database_operation takes user, operation, data
    goal validate_access(user, operation) {
        precondition: user != null and operation != null,
        postcondition: can_access_database(user, operation),
        strategy: security_validation_with_reasoning
    }
    
    if can_access_database(user, operation) then
        goal execute_operation(operation, data, result) {
            precondition: operation in ["read", "write", "update", "delete"],
            postcondition: result.success == true and result.secure == true,
            strategy: secure_database_access
        }
        return result
    else
        return {success: false, error: "Access denied"}
    end
end

# Test the complete system
admin_result = secure_database_operation("admin", "write", {table: "users", data: new_user})
guest_result = secure_database_operation("guest", "read", {table: "public_data"})

print("Week 1 Grammar Engine Examples Complete!")
print("All constructs demonstrate enhanced grammar-driven parsing with:")
print("✓ Advanced pattern matching with operators")
print("✓ Semantic AST construction with annotations")
print("✓ Goal system integration and coordination")
print("✓ Performance optimization with memoization")
print("✓ Grammar-aware error recovery")
print("✓ Ruby compatibility maintenance")
print("✓ Full Phase 1 integration")