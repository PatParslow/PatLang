# Phase 1 Core Parser Framework Examples
# Demonstrates basic parsing capabilities implemented in Phase 1

# Basic arithmetic expressions - Phase 1 Success Criteria
2 + 3 * 4
(5 + 2) / 3
10 - 4 + 1
2 * 3 * 4

# Variable handling - Phase 1 Success Criteria
x
my_variable
_private
user_input

# Assignment statements - Phase 1 Success Criteria
x = 5
result = x + y
total = 2 + 3 * 4
counter = counter + 1

# Function calls in expressions
add(2, 3)
multiply(x, y)
calculate(a, b, c)

# Parenthesized expressions
(x + y) * z
((a + b) * c) / d
(result)

# Boolean expressions
true
false
x == y
a != b
value > 0
count <= limit

# Logical operations
x and y
a or b
not finished
x and (y or z)

# Unary operations
-x
-42
not ready

# Nested function calls
add(multiply(2, 3), 4)
calculate(get_value(), process(data))

# Complex expressions combining multiple features
result = (x + y) * calculate(a, b) - offset
final_value = process(input_data) and validate(result_set)
adjusted_total = base_amount + tax_rate * base_amount

# String literals
"hello world"
"This is a test string"
name = "John Doe"

# Mixed type expressions
message = "Result: " + calculate_result()
display_text = "Value is " + value

# Error cases that should be handled gracefully
# These should generate error nodes but continue parsing

# Syntax errors with recovery
x + * y          # Missing operand - should recover
(incomplete      # Unclosed parenthesis - should auto-complete
42 +             # Missing right operand - should insert placeholder

# Invalid identifiers
123abc           # Should treat as separate tokens
$invalid         # Should treat as identifier or error token

# Unterminated strings
"unclosed string # Should auto-close

# Multiple errors in sequence
x + * y + / z    # Multiple operator errors - should recover from each

# Comments demonstrating error recovery
# The parser should continue processing after each error
# and provide meaningful error messages with suggestions