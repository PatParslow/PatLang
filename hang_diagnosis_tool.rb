#!/usr/bin/env ruby
# frozen_string_literal: true

require 'timeout'
require 'minitest/autorun'
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/ast_nodes'

class HangDiagnosisTool
  def initialize
    @timeout_seconds = 10
    @results = {}
  end

  def parse_and_evaluate(input)
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    evaluator.evaluate(ast)
  end

  def test_with_timeout(test_name, input, expected_result = nil)
    puts "Testing: #{test_name}"
    start_time = Time.now
    
    begin
      result = Timeout.timeout(@timeout_seconds) do
        parse_and_evaluate(input)
      end
      
      elapsed = Time.now - start_time
      status = expected_result ? (result == expected_result ? "PASS" : "FAIL") : "COMPLETED"
      
      @results[test_name] = {
        status: status,
        elapsed_time: elapsed,
        result: result,
        error: nil
      }
      
      puts "  ✓ #{status} (#{elapsed.round(3)}s)"
      puts "    Result: #{result.inspect}" if result
      
    rescue Timeout::Error
      elapsed = Time.now - start_time
      @results[test_name] = {
        status: "TIMEOUT",
        elapsed_time: elapsed,
        result: nil,
        error: "Test exceeded #{@timeout_seconds} seconds"
      }
      
      puts "  ✗ TIMEOUT after #{elapsed.round(3)}s"
      
    rescue => e
      elapsed = Time.now - start_time
      @results[test_name] = {
        status: "ERROR",
        elapsed_time: elapsed,
        result: nil,
        error: e.message
      }
      
      puts "  ✗ ERROR (#{elapsed.round(3)}s): #{e.message}"
    end
    
    puts
  end

  def run_individual_tests
    puts "=" * 60
    puts "HANG DIAGNOSIS - INDIVIDUAL TEST ISOLATION"
    puts "=" * 60
    puts

    # Test 1: Simple function definition and call
    test_with_timeout("simple_function_definition_and_call", <<~PATLANG, "Hello, World!")
      make a function called greet {
        return "Hello, World!"
      }
      call greet
    PATLANG

    # Test 2: Function with parameters
    test_with_timeout("function_with_parameters", <<~PATLANG, 8)
      make a function called add takes: x, y {
        return x + y
      }
      call add with 5, 3
    PATLANG

    # Test 3: Recursive factorial (potential hanging point)
    test_with_timeout("recursive_factorial", <<~PATLANG, 120)
      make a function called factorial takes: n {
        if n <= 1 then
          return 1
        else
          return n * (call factorial with n - 1)
        end
      }
      call factorial with 5
    PATLANG

    # Test 4: Recursive fibonacci (high computational complexity)
    test_with_timeout("recursive_fibonacci", <<~PATLANG, 21)
      make a function called fib takes: n {
        if n <= 1 then
          return n
        else
          return (call fib with n - 1) + (call fib with n - 2)
        end
      }
      call fib with 8
    PATLANG

    # Test 5: Tail recursive countdown
    test_with_timeout("tail_recursive_countdown", <<~PATLANG, "Done!")
      make a function called countdown takes: n {
        if n <= 0 then
          return "Done!"
        else
          return call countdown with n - 1
        end
      }
      call countdown with 3
    PATLANG

    # Test 6: Nested function calls
    test_with_timeout("nested_function_calls", <<~PATLANG, 30)
      make a function called double takes: x {
        return x * 2
      }
      
      make a function called triple takes: x {
        return x * 3
      }
      
      call double with call triple with 5
    PATLANG

    # Test 7: Complex string operations with recursion
    test_with_timeout("repeat_word_recursive", <<~PATLANG, "hello hello hello")
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

    # Test 8: Calculator functions (multiple function definitions)
    test_with_timeout("calculator_functions", <<~PATLANG, 125)
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
  end

  def print_summary
    puts "=" * 60
    puts "HANG DIAGNOSIS SUMMARY"
    puts "=" * 60
    puts

    timeouts = @results.select { |_, result| result[:status] == "TIMEOUT" }
    errors = @results.select { |_, result| result[:status] == "ERROR" }
    passes = @results.select { |_, result| result[:status] == "PASS" }
    completed = @results.select { |_, result| result[:status] == "COMPLETED" }

    puts "Results Summary:"
    puts "  PASSED: #{passes.count}"
    puts "  COMPLETED: #{completed.count}"
    puts "  ERRORS: #{errors.count}"
    puts "  TIMEOUTS: #{timeouts.count}"
    puts

    if timeouts.any?
      puts "HANGING TESTS (TIMEOUTS):"
      timeouts.each do |test_name, result|
        puts "  ✗ #{test_name} - #{result[:error]}"
      end
      puts
    end

    if errors.any?
      puts "ERROR TESTS:"
      errors.each do |test_name, result|
        puts "  ✗ #{test_name} - #{result[:error]}"
      end
      puts
    end

    # Performance analysis
    puts "PERFORMANCE ANALYSIS:"
    @results.sort_by { |_, result| result[:elapsed_time] }.reverse.each do |test_name, result|
      status_symbol = case result[:status]
                      when "PASS", "COMPLETED" then "✓"
                      when "TIMEOUT" then "⏱"
                      when "ERROR" then "✗"
                      else "?"
                      end
      puts "  #{status_symbol} #{test_name}: #{result[:elapsed_time].round(3)}s"
    end
  end

  def run_diagnosis
    run_individual_tests
    print_summary
    
    # Return analysis
    timeouts = @results.select { |_, result| result[:status] == "TIMEOUT" }
    
    if timeouts.any?
      puts "\n" + "=" * 60
      puts "DIAGNOSIS: HANGING DETECTED"
      puts "=" * 60
      puts "The following tests are hanging:"
      timeouts.each { |name, _| puts "  - #{name}" }
      
      return {
        status: :hanging_detected,
        hanging_tests: timeouts.keys,
        total_tests: @results.count,
        results: @results
      }
    else
      puts "\n" + "=" * 60
      puts "DIAGNOSIS: NO HANGING DETECTED"
      puts "=" * 60
      puts "All tests completed within timeout period."
      
      return {
        status: :no_hanging,
        hanging_tests: [],
        total_tests: @results.count,
        results: @results
      }
    end
  end
end

# Run the diagnosis if this file is executed directly
if __FILE__ == $0
  puts "Starting hang diagnosis for function integration tests..."
  puts "Timeout per test: 10 seconds"
  puts
  
  tool = HangDiagnosisTool.new
  diagnosis = tool.run_diagnosis
  
  puts "\nDiagnosis complete!"
  exit(diagnosis[:hanging_tests].any? ? 1 : 0)
end