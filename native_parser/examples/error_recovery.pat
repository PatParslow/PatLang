# Error Recovery Examples - Error handling demonstrations
# These examples showcase the parser's error recovery capabilities

# Syntax errors that should be recoverable
# Missing closing parenthesis
result = calculate(2 + 3
# Parser should insert missing ')' and continue

# Unexpected token
x = 5 @ 3
# Parser should treat '@' as unknown token and continue

# Missing 'then' keyword
if x > 5
    print("greater")
end
# Parser should suggest inserting 'then'

# Unterminated string
message = "hello world
# Parser should auto-close the string

# Missing 'end' keyword
make a function called test takes x
    return x * 2
# Parser should suggest adding 'end'

# Typos in keywords
funciton add(x, y)
    retrun x + y
# Parser should suggest corrections: 'function', 'return'

# Invalid reasoning syntax
fact parent john, mary)
# Parser should suggest proper syntax: fact parent(john, mary)

# Missing operators
x = 5 3
# Parser should suggest inserting operator: x = 5 * 3

# Incomplete expressions
if x > then
    print("test")
end
# Parser should suggest completing the condition

# Mixed valid and invalid syntax
# Valid code
x = 10
y = 20

# Error in middle
z = x +
# Missing operand - parser should suggest completion

# More valid code following error
w = x * y
print(w)

# Nested errors
if x > 5 then
    if y < then  # Incomplete condition
        print("nested error"
    # Missing end for inner if
# Missing end for outer if

# The parser should recover from all errors above and continue parsing