require_relative 'test_helper'
require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/evaluator'

class TestFunctionIntegration < Minitest::Test
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

  # Integration with Control Flow Tests

  def test_function_with_if_statement_integration
    input = <<~PATLANG
      make a function called absolute takes: x {
        if x < 0 then
          return 0 - x
        else
          return x
        end
      }
      call absolute with -10
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 10, result
  end

  def test_function_with_nested_if_statements
    input = <<~PATLANG
      make a function called grade_classifier takes: score {
        if score >= 90 then
          return "A"
        else
          if score >= 80 then
            return "B"
          else
            if score >= 70 then
              return "C"
            else
              return "F"
            end
          end
        end
      }
      call grade_classifier with 85
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "B", result
  end

  def test_function_with_while_loop_integration
    input = <<~PATLANG
      make a function called sum_to_n takes: n {
        total = 0
        i = 1
        while i <= n do
          total = total + i
          i = i + 1
        end
        return total
      }
      call sum_to_n with 5
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 15, result
  end

  def test_function_with_for_loop_integration
    skip "For loops not yet implemented in v0.5.0"
  end

  # Integration with String Operations Tests

  def test_function_with_string_concatenation
    input = <<~PATLANG
      make a function called full_name takes: first, last {
        return first + " " + last
      }
      call full_name with "John", "Doe"
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "John Doe", result
  end

  def test_function_with_string_methods
    input = <<~PATLANG
      make a function called format_name takes: name {
        uppercase_name = name.uppercase()
        return "Hello, " + uppercase_name + "!"
      }
      call format_name with "alice"
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Hello, ALICE!", result
  end

  def test_function_with_multiple_string_operations
    input = <<~PATLANG
      make a function called process_input takes: text {
        trimmed = text.trim()
        upper = trimmed.uppercase()
        return "Processed: " + upper
      }
      call process_input with "  hello world  "
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Processed: HELLO WORLD", result
  end

  # Complex Nested Function Scenarios

  def test_function_calling_multiple_functions
    input = <<~PATLANG
      make a function called double takes: x {
        return x * 2
      }
      
      make a function called square takes: x {
        return x * x
      }
      
      make a function called complex_calc takes: x {
        doubled = call double with x
        squared = call square with doubled
        return squared
      }
      
      call complex_calc with 3
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 36, result # (3 * 2)^2 = 6^2 = 36
  end

  def test_deeply_nested_function_calls
    input = <<~PATLANG
      make a function called add_one takes: x {
        return x + 1
      }
      
      make a function called nested_calls takes: x {
        return call add_one with call add_one with call add_one with x
      }
      
      call nested_calls with 5
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 8, result # 5 + 1 + 1 + 1
  end

  def test_functions_with_conditional_calls
    input = <<~PATLANG
      make a function called positive takes: x {
        return x
      }
      
      make a function called negative takes: x {
        return 0 - x
      }
      
      make a function called conditional_call takes: x, use_positive {
        if use_positive then
          return call positive with x
        else
          return call negative with x
        end
      }
      
      call conditional_call with 5, false
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal -5, result
  end

  # Functions with Various Data Types

  def test_function_with_number_operations
    input = <<~PATLANG
      make a function called calculate takes: a, b, c {
        sum = a + b
        product = sum * c
        return product / 2
      }
      call calculate with 3, 7, 4
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 20.0, result # (3 + 7) * 4 / 2 = 40 / 2 = 20
  end

  def test_function_with_boolean_logic
    input = <<~PATLANG
      make a function called logical_and takes: a, b {
        return a && b
      }
      call logical_and with true, false
    PATLANG
    
    # Skip until boolean operators are implemented
    skip "Boolean operators not yet implemented"
  end

  def test_function_with_mixed_data_types
    input = <<~PATLANG
      make a function called format_result takes: name, score, passed {
        if passed then
          status = "PASSED"
        else
          status = "FAILED"
        end
        return name + ": " + score + " - " + status
      }
      call format_result with "Alice", "95", true
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Alice: 95 - PASSED", result
  end

  # Performance Testing for Recursive Functions

  def test_factorial_performance
    input = <<~PATLANG
      make a function called factorial takes: n {
        if n <= 1 then
          return 1
        else
          return n * call factorial with n - 1
        end
      }
      call factorial with 10
    PATLANG
    
    start_time = Time.now
    result = parse_and_evaluate(input)
    end_time = Time.now
    
    assert_equal 3628800, result # 10!
    assert (end_time - start_time) < 1.0, "Factorial should complete within 1 second"
  end

  def test_fibonacci_performance
    input = <<~PATLANG
      make a function called fib takes: n {
        if n <= 2 then
          return 1
        else
          return (call fib with n - 1) + (call fib with n - 2)
        end
      }
      call fib with 8
    PATLANG
    
    start_time = Time.now
    result = parse_and_evaluate(input)
    end_time = Time.now
    
    assert_equal 21, result # fib(8)
    assert (end_time - start_time) < 2.0, "Fibonacci should complete within 2 seconds"
  end

  # Advanced Scope and Variable Management

  def test_function_scope_isolation
    input = <<~PATLANG
      global_var = 100
      
      make a function called scope_test takes: x {
        global_var = 200  # This should not affect global scope
        local_var = x * 2
        return local_var
      }
      
      result = call scope_test with 5
      result + global_var  # Should be 10 + 100 = 110
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 110, result
  end

  def test_parameter_shadowing
    input = <<~PATLANG
      x = 50
      
      make a function called shadow_test takes: x {
        return x * 3  # Should use parameter x, not global x
      }
      
      call shadow_test with 10
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 30, result
  end

  def test_nested_function_scopes
    input = <<~PATLANG
      outer_var = 1
      
      make a function called outer takes: a {
        outer_var = 2  # Local to outer function
        
        make a function called inner takes: b {
          outer_var = 3  # Local to inner function
          return a + b + outer_var
        }
        
        inner_result = call inner with 10
        return inner_result + outer_var  # Should use outer's outer_var (2)
      }
      
      call outer with 5
    PATLANG
    
    result = parse_and_evaluate(input)
    # inner: 5 + 10 + 3 = 18
    # outer: 18 + 2 = 20
    assert_equal 20, result
  end

  # Error Handling and Edge Cases

  def test_function_with_runtime_error_handling
    input = <<~PATLANG
      make a function called safe_divide takes: a, b {
        if b == 0 then
          return "Cannot divide by zero"
        else
          return a / b
        end
      }
      call safe_divide with 10, 0
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal "Cannot divide by zero", result
  end

  def test_function_parameter_count_validation
    input = <<~PATLANG
      make a function called test_func takes: a, b {
        return a + b
      }
      call test_func with 5  # Wrong number of arguments
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_match(/expects 2 arguments, got 1/, error.message)
  end

  def test_undefined_function_call_error
    input = <<~PATLANG
      call nonexistent_function with 5
    PATLANG
    
    error = assert_raises(RuntimeError) do
      parse_and_evaluate(input)
    end
    assert_match(/Undefined function/, error.message)
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
      
      result = call multiply with 3, 4 + call add with 2, 3
      result
    PATLANG
    
    result = parse_and_evaluate(input)
    assert_equal 17, result # 3 * 4 + (2 + 3) = 12 + 5 = 17
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
      
      call add with call multiply with sum, diff, prod
    PATLANG
    
    result = parse_and_evaluate(input)
    # sum = 15, diff = 5, prod = 50
    # (15 * 5) + 50 = 75 + 50 = 125
    assert_equal 125, result
  end

  def test_text_processing_functions
    input = <<~PATLANG
      make a function called word_count takes: text {
        # Simplified word count - count spaces + 1
        words = 1
        i = 0
        while i < text.length() do
          if text.at(i) == " " then
            words = words + 1
          end
          i = i + 1
        end
        return words
      }
      
      make a function called format_report takes: text {
        count = call word_count with text
        return "Text: '" + text + "' has " + count + " words"
      }
      
      call format_report with "Hello world example"
    PATLANG
    
    # Skip until string indexing is implemented
    skip "String indexing not yet implemented"
  end
end