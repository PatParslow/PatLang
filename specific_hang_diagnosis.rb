#!/usr/bin/env ruby
# frozen_string_literal: true

require 'timeout'
require 'minitest/autorun'
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/ast_nodes'

class SpecificHangDiagnosis
  def initialize
    @timeout_seconds = 5
  end

  def parse_and_evaluate(input)
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    evaluator.evaluate(ast)
  end

  def test_undefined_function_call_with_logging
    puts "=" * 60
    puts "TESTING: test_undefined_function_call (the hanging test)"
    puts "=" * 60
    
    input = <<~PATLANG
      call nonexistent_function
    PATLANG
    
    puts "Input PATLang code:"
    puts input
    puts
    
    puts "Starting evaluation with detailed logging..."
    start_time = Time.now
    
    begin
      Timeout.timeout(@timeout_seconds) do
        puts "1. Creating lexer..."
        lexer = Lexer.new(input)
        
        puts "2. Tokenizing..."
        tokens = lexer.tokenize
        puts "   Tokens: #{tokens.map(&:type)}"
        
        puts "3. Creating parser..."
        parser = Parser.new(tokens)
        
        puts "4. Parsing..."
        ast = parser.parse
        puts "   AST: #{ast.class}"
        
        puts "5. Creating evaluator..."
        evaluator = Evaluator.new
        
        puts "6. Evaluating..."
        result = evaluator.evaluate(ast)
        puts "   Result: #{result}"
        
        puts "7. Evaluation completed successfully!"
        return result
      end
      
    rescue Timeout::Error
      elapsed = Time.now - start_time
      puts "✗ TIMEOUT after #{elapsed.round(3)}s - this is where the hang occurs!"
      return :timeout
      
    rescue => e
      elapsed = Time.now - start_time
      puts "✓ ERROR as expected (#{elapsed.round(3)}s): #{e.class} - #{e.message}"
      return :error_as_expected
    end
  end

  def test_function_parameter_count_validation_with_logging
    puts "=" * 60
    puts "TESTING: test_function_parameter_count_validation (another error test)"
    puts "=" * 60
    
    input = <<~PATLANG
      make a function called test takes: a, b {
        return a + b
      }
      call test with 5
    PATLANG
    
    puts "Input PATLang code:"
    puts input
    puts
    
    puts "Starting evaluation with detailed logging..."
    start_time = Time.now
    
    begin
      Timeout.timeout(@timeout_seconds) do
        puts "1. Creating lexer..."
        lexer = Lexer.new(input)
        
        puts "2. Tokenizing..."
        tokens = lexer.tokenize
        puts "   Tokens: #{tokens.map(&:type).take(10)}..." # Show first 10 tokens
        
        puts "3. Creating parser..."
        parser = Parser.new(tokens)
        
        puts "4. Parsing..."
        ast = parser.parse
        puts "   AST: #{ast.class}"
        
        puts "5. Creating evaluator..."
        evaluator = Evaluator.new
        
        puts "6. Evaluating..."
        result = evaluator.evaluate(ast)
        puts "   Result: #{result}"
        
        puts "7. Evaluation completed successfully!"
        return result
      end
      
    rescue Timeout::Error
      elapsed = Time.now - start_time
      puts "✗ TIMEOUT after #{elapsed.round(3)}s - this is where the hang occurs!"
      return :timeout
      
    rescue => e
      elapsed = Time.now - start_time
      puts "✓ ERROR as expected (#{elapsed.round(3)}s): #{e.class} - #{e.message}"
      return :error_as_expected
    end
  end

  def test_zero_params_with_args_with_logging
    puts "=" * 60
    puts "TESTING: test_function_with_zero_parameters_called_with_arguments"
    puts "=" * 60
    
    input = <<~PATLANG
      make a function called no_params {
        return "no params"
      }
      call no_params with 1, 2, 3
    PATLANG
    
    puts "Input PATLang code:"
    puts input
    puts
    
    puts "Starting evaluation with detailed logging..."
    start_time = Time.now
    
    begin
      Timeout.timeout(@timeout_seconds) do
        puts "1. Creating lexer..."
        lexer = Lexer.new(input)
        
        puts "2. Tokenizing..."
        tokens = lexer.tokenize
        puts "   Tokens: #{tokens.map(&:type).take(10)}..." # Show first 10 tokens
        
        puts "3. Creating parser..."
        parser = Parser.new(tokens)
        
        puts "4. Parsing..."
        ast = parser.parse
        puts "   AST: #{ast.class}"
        
        puts "5. Creating evaluator..."
        evaluator = Evaluator.new
        
        puts "6. Evaluating..."
        result = evaluator.evaluate(ast)
        puts "   Result: #{result}"
        
        puts "7. Evaluation completed successfully!"
        return result
      end
      
    rescue Timeout::Error
      elapsed = Time.now - start_time
      puts "✗ TIMEOUT after #{elapsed.round(3)}s - this is where the hang occurs!"
      return :timeout
      
    rescue => e
      elapsed = Time.now - start_time
      puts "✓ ERROR as expected (#{elapsed.round(3)}s): #{e.class} - #{e.message}"
      return :error_as_expected
    end
  end

  def run_diagnosis
    puts "Starting specific hang diagnosis..."
    puts "Focusing on error-handling tests that might be hanging"
    puts
    
    results = {}
    
    # Test the specific hanging case
    results[:undefined_function] = test_undefined_function_call_with_logging
    puts
    
    # Test other error cases
    results[:parameter_count] = test_function_parameter_count_validation_with_logging
    puts
    
    results[:zero_params_with_args] = test_zero_params_with_args_with_logging
    puts
    
    puts "=" * 60
    puts "DIAGNOSIS RESULTS"
    puts "=" * 60
    
    results.each do |test_name, result|
      status = case result
               when :timeout then "HANGING"
               when :error_as_expected then "WORKING"
               else "UNEXPECTED: #{result}"
               end
      puts "#{test_name}: #{status}"
    end
    
    hanging_tests = results.select { |_, result| result == :timeout }
    
    if hanging_tests.any?
      puts "\n🔍 HANGING DETECTED IN:"
      hanging_tests.each { |test_name, _| puts "  - #{test_name}" }
      puts "\n💡 HYPOTHESIS: The hang occurs during error handling evaluation"
      puts "   Likely in the function lookup or exception raising process"
    else
      puts "\n✅ NO HANGING DETECTED"
      puts "   All error-handling tests work correctly"
    end
    
    results
  end
end

# Run the diagnosis if this file is executed directly
if __FILE__ == $0
  tool = SpecificHangDiagnosis.new
  tool.run_diagnosis
end