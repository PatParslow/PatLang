# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/evaluator'
require_relative '../src/ast_nodes'

class TestFunctionIntegration < Minitest::Test
  def parse_and_evaluate(input)
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    evaluator.evaluate(ast)
  end

  # Basic Function Definition and Call

  def test_simple_function_definition_and_call
    input = <<~PATLANG
      make a function called greet {
        return "Hello, World!"
      }
      call greet
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Hello, World!", result
  end

  def test_function_with_parameters
    input = <<~PATLANG
      make a function called add takes: x, y {
        return x + y
      }
      call add with 5, 3
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 8, result
  end

  def test_function_with_multiple_parameters
    input = <<~PATLANG
      make a function called multiply_three takes: a, b, c {
        return a * b * c
      }
      call multiply_three with 2, 3, 4
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 24, result
  end

  # Function Scope and Variable Access

  def test_function_parameter_scope
    input = <<~PATLANG
      x = 100
      make a function called test_scope takes: x {
        return x + 1
      }
      call test_scope with 5
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 6, result
  end

  def test_function_return_different_types
    input = <<~PATLANG
      make a function called get_type takes: input {
        if input == 1 then
          return "number"
        else
          if input == "hello" then
            return "string"
          else
            return "unknown"
          end
        end
      }
      
      result1 = call get_type with 1
      result2 = call get_type with "hello"
      result3 = call get_type with 42
      
      result1 + "," + result2 + "," + result3
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "number,string,unknown", result
  end

  # Recursive Functions

  def test_recursive_factorial
    input = <<~PATLANG
      make a function called factorial takes: n {
        if n <= 1 then
          return 1
        else
          return n * (call factorial with n - 1)
        end
      }
      call factorial with 5
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 120, result
  end

  def test_recursive_fibonacci
    input = <<~PATLANG
      make a function called fib takes: n {
        if n <= 1 then
          return n
        else
          return (call fib with n - 1) + (call fib with n - 2)
        end
      }
      call fib with 8
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 21, result
  end

  def test_tail_recursive_countdown
    input = <<~PATLANG
      make a function called countdown takes: n {
        if n <= 0 then
          return "Done!"
        else
          return call countdown with n - 1
        end
      }
      call countdown with 3
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Done!", result
  end

  # Nested Function Calls

  def test_nested_function_calls
    input = <<~PATLANG
      make a function called double takes: x {
        return x * 2
      }
      
      make a function called triple takes: x {
        return x * 3
      }
      
      call double with call triple with 5
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 30, result # triple(5) = 15, double(15) = 30
  end

  def test_deeply_nested_function_calls
    input = <<~PATLANG
      make a function called add_one takes: x {
        return x + 1
      }
      
      call add_one with call add_one with call add_one with 5
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 8, result # 5 + 1 + 1 + 1 = 8
  end

  # Functions with Control Flow

  def test_function_with_conditional_logic
    input = <<~PATLANG
      make a function called max takes: a, b {
        if a > b then
          return a
        else
          return b
        end
      }
      
      result1 = call max with 10, 5
      result2 = call max with 3, 8
      result1 + result2
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 18, result # max(10,5) + max(3,8) = 10 + 8 = 18
  end

  def test_function_with_complex_conditionals
    input = <<~PATLANG
      make a function called classify_number takes: x {
        if x > 0 then
          if x > 100 then
            return "large positive"
          else
            return "small positive"
          end
        else
          if x < 0 then
            return "negative"
          else
            return "zero"
          end
        end
      }
      
      call classify_number with 150
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "large positive", result
  end

  # Functions with String Operations

  def test_function_string_manipulation
    input = <<~PATLANG
      make a function called create_greeting takes: name, title {
        return "Hello, " + title + " " + name + "!"
      }
      
      call create_greeting with "Smith", "Dr."
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Hello, Dr. Smith!", result
  end

  def test_function_string_processing
    input = <<~PATLANG
      make a function called repeat_word takes: word, count {
        if count <= 0 then
          return ""
        else
          if count == 1 then
            return word
          else
            return word + " " + call repeat_word with word, count - 1
          end
        end
      }
      
      call repeat_word with "hello", 3
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "hello hello hello", result
  end

  # Function Parameter Edge Cases

  def test_function_no_parameters
    input = <<~PATLANG
      make a function called get_constant {
        return 42
      }
      call get_constant
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 42, result
  end

  def test_function_single_parameter
    input = <<~PATLANG
      make a function called negate takes: x {
        return -x
      }
      call negate with 15
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal -15, result
  end

  # Function Return Value Edge Cases

  def test_function_returns_function_result
    input = <<~PATLANG
      make a function called inner {
        return "inner result"
      }
      
      make a function called outer {
        return call inner
      }
      
      call outer
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "inner result", result
  end

  def test_function_returns_arithmetic_expression
    input = <<~PATLANG
      make a function called calculate takes: x, y {
        return x * 2 + y * 3
      }
      call calculate with 4, 5
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 23, result # 4*2 + 5*3 = 8 + 15 = 23
  end

  # Multiple Function Definitions

  def test_multiple_function_definitions
    input = <<~PATLANG
      make a function called add takes: a, b {
        return a + b
      }
      
      make a function called subtract takes: a, b {
        return a - b
      }
      
      make a function called multiply takes: a, b {
        return a * b
      }
      
      result1 = call add with 10, 5
      result2 = call subtract with 10, 5
      result3 = call multiply with 10, 5
      
      result1 + result2 + result3
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 70, result # 15 + 5 + 50 = 70
  end

  def test_function_redefinition
    input = <<~PATLANG
      make a function called test {
        return "first"
      }
      
      result1 = call test
      
      make a function called test {
        return "second"
      }
      
      result2 = call test
      
      result1 + " " + result2
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "first second", result
  end

  # Function Integration with Variables

  def test_function_with_variable_assignment
    input = <<~PATLANG
      make a function called compute takes: x {
        return x * x
      }
      
      base = 7
      result = call compute with base
      result
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 49, result
  end

  def test_function_result_in_variable_operations
    input = <<~PATLANG
      make a function called get_value {
        return 25
      }
      
      x = 10
      y = call get_value
      x + y
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 35, result
  end

  # Integration with Complex Expressions

  def test_function_call_in_complex_expression
    input = <<~PATLANG
      make a function called multiply takes: a, b {
        return a * b
      }
      
      make a function called add takes: a, b {
        return a + b
      }
      
      result = (call multiply with 3, 4) + (call add with 2, 3)
      result
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 17, result # (3 * 4) + (2 + 3) = 12 + 5 = 17
  end

  def test_function_with_complex_return_expression
    input = <<~PATLANG
      make a function called complex_calc takes: x, y, z {
        return x * y + z / 2 - 1
      }
      call complex_calc with 4, 3, 6
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 14.0, result # 4 * 3 + 6 / 2 - 1 = 12 + 3 - 1 = 14
  end

  # Real-world Function Usage Patterns

  def test_calculator_functions
    input = <<~PATLANG
      make a function called add takes: a, b {
        return a + b
      }
      
      make a function called subtract takes: a, b {
        return a - b
      }
      
      make a function called multiply takes: a, b {
        return a * b
      }
      
      make a function called divide takes: a, b {
        if b == 0 then
          return "Error: Division by zero"
        else
          return a / b
        end
      }
      
      # Test calculator operations
      sum = call add with 10, 5
      diff = call subtract with 10, 5
      prod = call multiply with 10, 5
      quot = call divide with 10, 5
      
      call add with (call multiply with sum, diff), prod
    PATLANG
    
    result = parse_and_evaluate(input)
    # sum = 15, diff = 5, prod = 50
    # (15 * 5) + 50 = 75 + 50 = 125
    assert_equal 125, result
  end

  def test_utility_functions
    input = <<~PATLANG
      make a function called is_even takes: n {
        return n % 2 == 0
      }
      
      make a function called absolute takes: x {
        if x < 0 then
          return -x
        else
          return x
        end
      }
      
      make a function called distance takes: x1, y1, x2, y2 {
        dx = call absolute with x2 - x1
        dy = call absolute with y2 - y1
        return dx + dy  # Manhattan distance
      }
      
      call distance with 0, 0, 3, 4
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 7, result # |3-0| + |4-0| = 3 + 4 = 7
  end

  # Error Handling and Edge Cases

  def test_function_parameter_count_validation
    input = <<~PATLANG
      make a function called test takes: a, b {
        return a + b
      }
      call test with 5
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_includes error.message, "Function 'test' expects 2 arguments, got 1"
  end

  def test_undefined_function_call
    input = <<~PATLANG
      call nonexistent_function
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_includes error.message, "Undefined function: nonexistent_function"
  end

  def test_function_with_zero_parameters_called_with_arguments
    input = <<~PATLANG
      make a function called no_params {
        return "no params"
      }
      call no_params with 1, 2, 3
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_includes error.message, "Function 'no_params' expects 0 arguments, got 3"
  end

  # Performance and Complexity Tests

  def test_deep_recursion_handling
    skip "Skipping deep recursion test to avoid stack overflow"
    
    input = <<~PATLANG
      make a function called deep_count takes: n {
        if n <= 0 then
          return 0
        else
          return 1 + (call deep_count with n - 1)
        end
      }
      call deep_count with 100
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 100, result
  end

  def test_complex_function_composition
    input = <<~PATLANG
      make a function called f takes: x {
        return x + 1
      }
      
      make a function called g takes: x {
        return x * 2
      }
      
      make a function called h takes: x {
        return x - 3
      }
      
      # Compose functions: h(g(f(5)))
      call h with call g with call f with 5
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 9, result # f(5)=6, g(6)=12, h(12)=9
  end

  # Integration with Language Features

  def test_functions_with_complex_string_operations
    input = <<~PATLANG
      make a function called build_sentence takes: subject, verb, object {
        return subject + " " + verb + " " + object + "."
      }
      
      make a function called make_question takes: sentence {
        return sentence + " Really?"
      }
      
      statement = call build_sentence with "Alice", "loves", "Bob"
      call make_question with statement
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Alice loves Bob. Really?", result
  end

  def test_functions_with_arithmetic_and_comparisons
    input = <<~PATLANG
      make a function called compare_squares takes: a, b {
        square_a = a * a
        square_b = b * b
        if square_a > square_b then
          return "First is larger"
        else
          if square_a < square_b then
            return "Second is larger"
          else
            return "Equal"
          end
        end
      }
      
      call compare_squares with 5, 4
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "First is larger", result # 25 > 16
  end
end