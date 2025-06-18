#!/usr/bin/env ruby

require_relative '../patlang-core/evaluator/evaluator'
require_relative '../patlang-core/lexer/lexer'
require_relative '../patlang-core/parser/parser'

# Test cases for automatic output functionality
class TestAutoOutputFunctionality
  def initialize
    @test_count = 0
    @passed = 0
    @failed = 0
  end

  def run_all_tests
    puts "=" * 50
    puts "Testing Automatic Output Functionality"
    puts "=" * 50
    
    test_standalone_strings
    test_standalone_numbers
    test_standalone_expressions
    test_assignments_no_output
    test_conditionals_no_output
    test_mixed_program
    
    puts "\n" + "=" * 50
    puts "Test Results: #{@passed}/#{@test_count} passed"
    puts "=" * 50
    
    return @failed == 0
  end

  private

  def test_case(description)
    @test_count += 1
    print "Test #{@test_count}: #{description}... "
    
    begin
      yield
      @passed += 1
      puts "PASSED"
    rescue => e
      @failed += 1
      puts "FAILED: #{e.message}"
    end
  end

  def evaluate_code(code)
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    # Capture stdout to test auto-output
    original_stdout = $stdout
    $stdout = StringIO.new
    
    result = evaluator.evaluate(ast)
    output = $stdout.string
    
    $stdout = original_stdout
    
    [result, output]
  end

  def test_standalone_strings
    test_case("Standalone string should auto-output") do
      result, output = evaluate_code('"Hello World"')
      raise "Expected output 'Hello World', got '#{output.strip}'" unless output.strip == "Hello World"
      raise "Expected result 'Hello World', got '#{result}'" unless result == "Hello World"
    end
  end

  def test_standalone_numbers
    test_case("Standalone number should auto-output") do
      result, output = evaluate_code('42')
      # Numbers are formatted as floats by default in Patlang
      raise "Expected output '42.0', got '#{output.strip}'" unless output.strip == "42.0"
      raise "Expected result 42, got #{result}" unless result == 42
    end
  end

  def test_standalone_expressions
    test_case("Standalone expression should auto-output") do
      result, output = evaluate_code('5 + 3')
      raise "Expected output '8.0', got '#{output.strip}'" unless output.strip == "8.0"
      raise "Expected result 8.0, got #{result}" unless result == 8.0
    end
  end

  def test_assignments_no_output
    test_case("Assignments should not auto-output") do
      result, output = evaluate_code('x = 42')
      raise "Expected no output, got '#{output.strip}'" unless output.strip.empty?
      raise "Expected result 42, got #{result}" unless result == 42
    end
  end

  def test_conditionals_no_output
    test_case("Conditionals should not auto-output") do
      code = <<~CODE
        x = 10
        if x > 5 then
          result = "big"
        else
          result = "small"
        end
      CODE
      
      result, output = evaluate_code(code)
      raise "Expected no output, got '#{output.strip}'" unless output.strip.empty?
      raise "Expected result 'big', got '#{result}'" unless result == "big"
    end
  end

  def test_mixed_program
    test_case("Mixed program with auto-output and non-auto-output") do
      code = <<~CODE
        greeting = "Hello"
        "Starting program"
        name = "World"
        greeting + ", " + name + "!"
        x = 5 + 3
        "Result: " + x
      CODE
      
      result, output = evaluate_code(code)
      lines = output.strip.split("\n")
      
      raise "Expected 3 output lines, got #{lines.length}" unless lines.length == 3
      raise "Expected 'Starting program', got '#{lines[0]}'" unless lines[0] == "Starting program"
      raise "Expected 'Hello, World!', got '#{lines[1]}'" unless lines[1] == "Hello, World!"
      raise "Expected 'Result: 8', got '#{lines[2]}'" unless lines[2] == "Result: 8"
    end
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  require 'stringio'
  
  tester = TestAutoOutputFunctionality.new
  success = tester.run_all_tests
  
  exit(success ? 0 : 1)
end