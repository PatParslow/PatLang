# Test file for automatic output functionality

# These should auto-output:
"Hello World"
5 + 3
"Result: " + (10 * 2)

# These should NOT auto-output:
x = 42
greeting = "Hi there"

# This should auto-output:
"x is now: " + x

# These should NOT auto-output:
if x > 40 then
  result = "big number"
else
  result = "small number"
end

# This should auto-output:
result

# Test with variables
length = 10
"Length is: " + length