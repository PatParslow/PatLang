# Patlang Automatic Output Demo
# Demonstrates the new auto-output functionality for standalone expressions

# Welcome message (auto-outputs)
"=== Patlang Auto-Output Demo ==="
""

# Basic auto-output examples
"1. Basic Values:"
"Hello, World!"
42
3.14159

# Assignment examples (no auto-output)
"2. Assignments (no output):"
greeting = "Hi there"
x = 10
y = 20

# Expression auto-output
"3. Expressions (auto-output):"
x + y
"Sum of " + x + " and " + y + " is " + (x + y)

# String operations
"4. String Operations:"
name = "Patlang"
"Welcome to " + name + "!"
"Language name length: " + name.length

# Mathematical expressions
"5. Mathematical Expressions:"
5 + 3 * 2
(10 + 5) / 3
2.5 * 4

# Conditional example (no auto-output for the conditional itself)
"6. Conditionals:"
if x > 5 then
  result = "x is greater than 5"
else
  result = "x is not greater than 5"
end

# But the result variable auto-outputs when referenced
result

# Complex expressions
"7. Complex Expressions:"
base = "Result"
count = 3
separator = " -> "
base + separator + count + separator + (count * 2)

# Boolean expressions
"8. Boolean Values:"
x > 15
x < 15
x == 10

# Final message
""
"=== Demo Complete ==="
"All standalone expressions automatically output to console!"