# Patlang v0.5.0 Functions Demo
# Comprehensive showcase of function capabilities

# Simple function without parameters
make a function called greet {
  return "Hello, World!"
}

# Function with parameters
make a function called add takes: x, y {
  return x + y
}

# Function with return type annotation
make a function called square takes: x returns: number {
  return x * x
}

# Function with string operations
make a function called build_message takes: name, greeting {
  return greeting + " " + name + "!"
}

# Recursive function - factorial
make a function called factorial takes: n {
  if n <= 1 then
    return 1
  else
    return n * call factorial with n - 1
  end
}

# Recursive function - fibonacci
make a function called fibonacci takes: n {
  if n <= 2 then
    return 1
  else
    return call fibonacci with n - 1 + call fibonacci with n - 2
  end
}

# Function with control flow integration
make a function called classify_number takes: x {
  if x > 0 then
    return "positive"
  else
    if x < 0 then
      return "negative"
    else
      return "zero"
    end
  end
}

# Function with while loop
make a function called sum_range takes: start, end {
  total = 0
  current = start
  while current <= end do
    total = total + current
    current = current + 1
  end
  return total
}

# Function with string method integration
make a function called process_text takes: text {
  uppercase_text = text.uppercase()
  return "Processed: " + uppercase_text
}

# Function that calls another function
make a function called double takes: x {
  return x * 2
}

make a function called quadruple takes: x {
  return call double with call double with x
end

# Complex function with multiple operations
make a function called calculate_area takes: length, width {
  area = length * width
  if area > 100 then
    return "Large area: " + area
  else
    return "Small area: " + area
  end
}

# Demo execution examples:

# Basic function calls
print "=== Basic Function Calls ==="
call greet
call add with 5, 3
call square with 4

# String operations
print "=== String Operations ==="
call build_message with "Alice", "Hello"
call process_text with "hello world"

# Recursive functions
print "=== Recursive Functions ==="
call factorial with 5
call fibonacci with 6

# Control flow integration
print "=== Control Flow Integration ==="
call classify_number with 10
call classify_number with -5
call classify_number with 0

# Nested function calls
print "=== Nested Function Calls ==="
call quadruple with 3

# Complex scenarios
print "=== Complex Scenarios ==="
call sum_range with 1, 10
call calculate_area with 12, 8
call calculate_area with 5, 6