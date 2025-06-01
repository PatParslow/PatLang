require_relative 'test_helper'
require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/evaluator'

class TestFunctionEvaluator < Minitest::Test
  def setup
    @evaluator = Evaluator.new
  end

  def parse_and_evaluate(input)
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    @evaluator.evaluate(ast)
  end

  # Function Definition and Registration Tests

  def test_simple_function_definition
    input = <<~PATLANG
      make a function called greet {
        return "Hello World"
      }
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "greet", result
  end

  def test_function_definition_with_parameters
    input = <<~PATLANG
      make a function called add takes: x, y {
        return x + y
      }
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "add", result
  end

  def test_function_definition_with_return_type
    input = <<~PATLANG
      make a function called square takes: x returns: number {
        return x * x
      }
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "square", result
  end

  def test_function_overloading_validation_same_params
    input1 = <<~PATLANG
      make a function called test takes: x {
        return x
      }
    PATLANG
    
    input2 = <<~PATLANG
      make a function called test takes: y {
        return y * 2
      }
    PATLANG
    
    parse_and_evaluate(input1)
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input2)
    end
    assert_match(/Function 'test' with 1 parameters already exists/, error.message)
  end

  def test_function_overloading_different_params
    input1 = <<~PATLANG
      make a function called test takes: x {
        return x
      }
    PATLANG
    
    input2 = <<~PATLANG
      make a function called test takes: x, y {
        return x + y
      }
    PATLANG
    
    result1 = parse_and_evaluate(input1)
    result2 = parse_and_evaluate(input2)
    
    assert_equal "test", result1
    assert_equal "test", result2
  end

  # Function Call Execution Tests

  def test_simple_function_call_no_params
    input = <<~PATLANG
      make a function called greet {
        return "Hello World"
      }
      call greet()
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Hello World", result
  end

  def test_function_call_with_parameters
    input = <<~PATLANG
      make a function called add takes: x, y {
        return x + y
      }
      call add(5, 3)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 8, result
  end

  def test_function_call_with_string_parameters
    input = <<~PATLANG
      make a function called greet takes: name {
        return "Hello " + name
      }
      call greet("Alice")
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Hello Alice", result
  end

  def test_function_call_with_mixed_parameters
    input = <<~PATLANG
      make a function called repeat takes: text, count {
        return text + " " + count
      }
      call repeat("Hi", 3)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Hi 3", result
  end

  def test_undefined_function_call
    input = <<~PATLANG
      call undefined_function()
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_match(/Undefined function: undefined_function/, error.message)
  end

  def test_function_call_wrong_parameter_count
    input = <<~PATLANG
      make a function called add takes: x, y {
        return x + y
      }
      call add(5)
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_match(/Function 'add' expects 2 arguments, got 1/, error.message)
  end

  # Return Statement Tests

  def test_return_with_expression
    input = <<~PATLANG
      make a function called double takes: x {
        return x * 2
      }
      call double(7)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 14, result
  end

  def test_return_without_expression
    input = <<~PATLANG
      make a function called void_function {
        return
      }
      call void_function()
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_nil result
  end

  def test_early_return
    input = <<~PATLANG
      make a function called early_return takes: x {
        if x > 10 then
          return "big"
        else
          return "small"
        end
        return "never reached"
      }
      call early_return(15)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "big", result
  end

  def test_multiple_returns_in_branches
    input = <<~PATLANG
      make a function called classify takes: x {
        if x > 0 then
          return "positive"
        else
          return "non-positive"
        end
      }
      call classify(-5)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "non-positive", result
  end

  # Scope Management Tests

  def test_function_local_variables
    input = <<~PATLANG
      x = 10
      make a function called test {
        x = 20
        return x
      }
      call test()
      x
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 10, result  # Global x should remain unchanged
  end

  def test_parameter_shadowing_global_variables
    input = <<~PATLANG
      x = 100
      make a function called test takes: x {
        return x * 2
      }
      call test(5)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 10, result  # Parameter x should shadow global x
  end

  def test_function_parameter_isolation
    input = <<~PATLANG
      make a function called modify takes: x {
        x = x + 1
        return x
      }
      y = 5
      call modify(y)
      y
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 5, result  # Original y should remain unchanged
  end

  def test_nested_scope_access
    input = <<~PATLANG
      global_var = 42
      make a function called test {
        return global_var
      }
      call test()
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 42, result
  end

  # Recursive Function Tests

  def test_simple_recursion
    input = <<~PATLANG
      make a function called factorial takes: n {
        if n <= 1 then
          return 1
        else
          return n * call factorial(n - 1)
        end
      }
      call factorial(5)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 120, result
  end

  def test_recursive_fibonacci
    input = <<~PATLANG
      make a function called fib takes: n {
        if n <= 2 then
          return 1
        else
          return call fib(n - 1) + call fib(n - 2)
        end
      }
      call fib(6)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 8, result
  end

  def test_recursive_scope_isolation
    input = <<~PATLANG
      make a function called countdown takes: n {
        if n <= 0 then
          return "done"
        else
          temp = n
          return temp + " " + call countdown(n - 1)
        end
      }
      call countdown(3)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "3 2 1 done", result
  end

  # Integration with Control Flow Tests

  def test_function_with_if_statement
    input = <<~PATLANG
      make a function called abs takes: x {
        if x < 0 then
          return 0 - x
        else
          return x
        end
      }
      call abs(-5)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 5, result
  end

  def test_function_with_while_loop
    input = <<~PATLANG
      make a function called sum_to takes: n {
        total = 0
        i = 1
        while i <= n do
          total = total + i
          i = i + 1
        end
        return total
      }
      call sum_to(4)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 10, result
  end

  # Integration with String Operations Tests

  def test_function_with_string_methods
    input = <<~PATLANG
      make a function called process_string takes: text {
        return text.uppercase()
      }
      call process_string("hello")
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "HELLO", result
  end

  def test_function_with_string_concatenation
    input = <<~PATLANG
      make a function called build_greeting takes: first, last {
        return "Hello " + first + " " + last
      }
      call build_greeting("John", "Doe")
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Hello John Doe", result
  end

  # Nested Function Calls Tests

  def test_function_calls_another_function
    input = <<~PATLANG
      make a function called double takes: x {
        return x * 2
      }
      make a function called quadruple takes: x {
        return call double(call double(x))
      }
      call quadruple(3)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 12, result
  end

  def test_function_call_as_parameter
    input = <<~PATLANG
      make a function called add takes: x, y {
        return x + y
      }
      make a function called square takes: x {
        return x * x
      }
      call add(call square(3), call square(4))
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 25, result
  end

  # Complex Expression Tests

  def test_function_with_complex_expressions
    input = <<~PATLANG
      make a function called calculate takes: a, b, c {
        return (a + b) * c - a / 2
      }
      call calculate(10, 5, 3)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 40.0, result
  end

  def test_function_return_last_expression
    input = <<~PATLANG
      make a function called implicit_return takes: x {
        x + 1
      }
      call implicit_return(5)
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 6, result
  end

  # Error Handling Tests

  def test_function_with_runtime_error
    input = <<~PATLANG
      make a function called divide takes: x, y {
        return x / y
      }
      call divide(10, 0)
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_match(/Division by zero/, error.message)
  end

  def test_function_with_undefined_variable
    input = <<~PATLANG
      make a function called bad_function {
        return undefined_var
      }
      call bad_function()
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_match(/Undefined variable: undefined_var/, error.message)
  end

  # Advanced Scope Tests

  def test_multiple_function_scopes
    input = <<~PATLANG
      x = 1
      make a function called func1 {
        x = 2
        make a function called func2 {
          x = 3
          return x
        }
        call func2()
        return x
      }
      call func1()
      x
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 1, result  # Global x should remain unchanged
  end

  def test_function_modifying_global_through_scope
    input = <<~PATLANG
      counter = 0
      make a function called increment {
        counter = counter + 1
        return counter
      }
      call increment()
      call increment()
      counter
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 0, result  # Global counter remains unchanged due to function scope
  end
end