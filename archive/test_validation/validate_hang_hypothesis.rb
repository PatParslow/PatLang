#!/usr/bin/env ruby
# frozen_string_literal: true

require 'timeout'
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/ast_nodes'

class HangHypothesisValidator
  def initialize
    @timeout_seconds = 3
  end

  def test_hypothesis_with_logging
    puts "=" * 60
    puts "VALIDATING AST SERIALIZATION HANG HYPOTHESIS"
    puts "=" * 60
    
    input = <<~PATLANG
      call nonexistent_function
    PATLANG
    
    puts "1. Testing normal execution path (should hang)..."
    result1 = test_normal_execution(input)
    
    puts "\n2. Testing with modified function evaluator (should work)..."
    result2 = test_modified_execution(input)
    
    puts "\n" + "=" * 60
    puts "HYPOTHESIS VALIDATION RESULTS"
    puts "=" * 60
    
    if result1 == :timeout && result2 == :error_as_expected
      puts "✅ HYPOTHESIS CONFIRMED: AST serialization causes hang"
      puts "   - Normal execution: HANGS"
      puts "   - Modified execution: WORKS"
      return :hypothesis_confirmed
    elsif result1 == :timeout && result2 == :timeout
      puts "❓ HYPOTHESIS PARTIAL: Both executions hang"
      puts "   - Issue might be deeper in the evaluation chain"
      return :hypothesis_partial
    elsif result1 == :error_as_expected
      puts "❌ HYPOTHESIS REJECTED: Normal execution works"
      puts "   - Hang might be test framework related"
      return :hypothesis_rejected
    else
      puts "❓ HYPOTHESIS UNCLEAR: Unexpected results"
      puts "   - Result1: #{result1}, Result2: #{result2}"
      return :hypothesis_unclear
    end
  end

  private

  def test_normal_execution(input)
    puts "   Testing with standard PatlangFunctionError..."
    
    begin
      Timeout.timeout(@timeout_seconds) do
        lexer = Lexer.new(input)
        tokens = lexer.tokenize
        parser = Parser.new(tokens)
        ast = parser.parse
        evaluator = Evaluator.new
        result = evaluator.evaluate(ast)
        puts "   ✓ Completed successfully: #{result}"
        return :success
      end
    rescue Timeout::Error
      puts "   ✗ TIMEOUT - execution hangs"
      return :timeout
    rescue => e
      puts "   ✓ ERROR as expected: #{e.class} - #{e.message}"
      return :error_as_expected
    end
  end

  def test_modified_execution(input)
    puts "   Testing with modified function evaluator (safe exception)..."
    
    begin
      Timeout.timeout(@timeout_seconds) do
        # Create a modified function evaluator that avoids AST serialization
        lexer = Lexer.new(input)
        tokens = lexer.tokenize
        parser = Parser.new(tokens)
        ast = parser.parse
        evaluator = Evaluator.new
        
        # Monkey-patch the function evaluator to use safe error handling
        original_method = evaluator.instance_variable_get(:@function_evaluator).method(:visit_function_call_node)
        
        def evaluator.safe_function_call_evaluation(node)
          function_evaluator = @function_evaluator
          
          # Replicate the lookup logic but with safe error handling
          function_key = "#{node.function_name}_#{node.arguments.length}"
          function_def = @functions[function_key] || @functions[node.function_name]
          
          unless function_def
            matching_functions = @functions.select { |key, _| key.to_s.start_with?("#{node.function_name}_") }
            if matching_functions.any?
              function_def = matching_functions.values.first
            end
          end
          
          unless function_def
            # Create a SAFE exception without AST node serialization
            raise RuntimeError, "Undefined function: #{node.function_name}"
          end
          
          # If we get here, continue with normal evaluation
          function_evaluator.visit_function_call_node(node)
        end
        
        # Override the function call evaluation
        case ast
        when FunctionCallNode
          result = evaluator.safe_function_call_evaluation(ast)
        else
          result = evaluator.evaluate(ast)
        end
        
        puts "   ✓ Completed successfully: #{result}"
        return :success
      end
    rescue Timeout::Error
      puts "   ✗ TIMEOUT - still hangs even with modified evaluator"
      return :timeout
    rescue => e
      puts "   ✓ ERROR as expected: #{e.class} - #{e.message}"
      return :error_as_expected
    end
  end
end

# Additional test to check AST node structure
class ASTStructureInvestigator
  def investigate_ast_structure
    puts "\n" + "=" * 60
    puts "INVESTIGATING AST NODE STRUCTURE"
    puts "=" * 60
    
    input = "call nonexistent_function"
    
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    puts "AST Node Type: #{ast.class}"
    puts "AST Node Attributes:"
    
    ast.instance_variables.each do |var|
      value = ast.instance_variable_get(var)
      puts "  #{var}: #{value.class} - #{value.inspect}"
      
      # Check for potential circular references
      if value.respond_to?(:instance_variables) && !value.instance_variables.empty?
        puts "    Has nested instance variables: #{value.instance_variables}"
      end
    end
    
    # Test serialization safety
    puts "\nTesting AST node serialization safety:"
    
    begin
      Timeout.timeout(2) do
        str_representation = ast.to_s
        puts "  ✓ to_s works: #{str_representation}"
      end
    rescue Timeout::Error
      puts "  ✗ to_s HANGS"
    rescue => e
      puts "  ✗ to_s ERROR: #{e.message}"
    end
    
    begin
      Timeout.timeout(2) do
        inspect_representation = ast.inspect
        puts "  ✓ inspect works: #{inspect_representation}"
      end
    rescue Timeout::Error
      puts "  ✗ inspect HANGS"
    rescue => e
      puts "  ✗ inspect ERROR: #{e.message}"
    end
  end
end

# Run the validation if this file is executed directly
if __FILE__ == $0
  puts "Starting hang hypothesis validation..."
  
  validator = HangHypothesisValidator.new
  result = validator.test_hypothesis_with_logging
  
  investigator = ASTStructureInvestigator.new
  investigator.investigate_ast_structure
  
  puts "\n" + "=" * 60
  puts "VALIDATION COMPLETE"
  puts "=" * 60
  puts "Result: #{result}"
  
  exit(result == :hypothesis_confirmed ? 0 : 1)
end