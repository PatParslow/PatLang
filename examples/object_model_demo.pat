# Patlang Object Model Demonstration
# This file demonstrates the core object model capabilities
# when object mode is enabled in the evaluator

# Basic arithmetic that will create objects
x = 5 + 3
y = x * 2

# String operations that will create objects  
greeting = "Hello"
name = "World"
message = greeting + " " + name

# Boolean operations that will create objects
is_positive = x > 0
is_even = y % 2 == 0

# Control flow with objects
if is_positive then
  result = "positive number"
else
  result = "not positive"
end

# Function definition and call with objects
make function double(n) {
  return n * 2
}

doubled = call double(x)