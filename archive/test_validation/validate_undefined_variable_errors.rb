#!/usr/bin/env ruby

require_relative 'src/evaluator'
require_relative 'src/parser'
require_relative 'src/lexer'
require_relative 'src/reasoning/reasoning_coordinator'

# Test script to validate undefined variable error reduction
class UndefinedVariableErrorValidator
  def initialize
    @error_count = 0
    @errors_found = []
  end

  def run_validation
    puts "=== Validating Undefined Variable Errors (Before Fix) ==="
    
    test_goal_variable_access
    test_reasoning_integration_variables
    test_complex_goal_scenarios
    
    puts "\n=== Summary ==="
    puts "Total undefined variable errors detected: #{@error_count}"
    @errors_found.each_with_index do |error, i|
      puts "#{i+1}. #{error}"
    end
    
    @error_count
  end

  private

  def test_goal_variable_access
    puts "\n--- Testing Goal Variable Access ---"
    
    begin
      evaluator = Evaluator.new
      evaluator.enable_object_mode
      reasoning_coordinator = ReasoningCoordinator.new(evaluator)
      evaluator.set_reasoning_coordinator(reasoning_coordinator)
      
      # Enable reasoning mode
      reasoning_coordinator.enable_reasoning_mode
      
      # Test code with goal variables
      code = <<~PATLANG
        goal complex_search {
          postcondition: result > 50 and result < 60 and result.prime?
        }
        
        pursue complex_search
      PATLANG
      
      parser = Parser.new(Lexer.new(code))
      ast = parser.parse
      result = evaluator.evaluate(ast)
      
      puts "✓ complex_search goal executed successfully"
      
    rescue => e
      if e.message.include?("Undefined variable") || e.message.include?("complex_search")
        @error_count += 1
        @errors_found << "Goal variable 'complex_search' undefined: #{e.message}"
        puts "✗ Found undefined variable error: #{e.message}"
      else
        puts "✗ Other error: #{e.message}"
      end
    end
  end

  def test_reasoning_integration_variables
    puts "\n--- Testing Reasoning Integration Variables ---"
    
    begin
      evaluator = Evaluator.new
      evaluator.enable_object_mode
      reasoning_coordinator = ReasoningCoordinator.new(evaluator)
      evaluator.set_reasoning_coordinator(reasoning_coordinator)
      
      # Enable reasoning mode
      reasoning_coordinator.enable_reasoning_mode
      
      # Test code similar to reasoning integration tests
      code = <<~PATLANG
        goal discover_relationships {
          postcondition: knows(alice, Someone) and friend(Someone, alice)
        }
        
        # Try to access the goal variable
        pursue discover_relationships
      PATLANG
      
      parser = Parser.new(Lexer.new(code))
      ast = parser.parse
      result = evaluator.evaluate(ast)
      
      puts "✓ discover_relationships goal executed successfully"
      
    rescue => e
      if e.message.include?("Undefined variable") || e.message.include?("discover_relationships")
        @error_count += 1
        @errors_found << "Goal variable 'discover_relationships' undefined: #{e.message}"
        puts "✗ Found undefined variable error: #{e.message}"
      else
        puts "✗ Other error: #{e.message}"
      end
    end
  end

  def test_complex_goal_scenarios
    puts "\n--- Testing Complex Goal Scenarios ---"
    
    # Test variable scoping in nested goal contexts
    test_cases = [
      {
        name: "nested_goal_variables",
        code: <<~PATLANG
          goal find_even {
            postcondition: result.even? and result > 10
          }
          
          goal optimize(obj) {
            postcondition: obj.value % 7 == 0 and obj.value < 100
          }
          
          pursue find_even
        PATLANG
      },
      {
        name: "goal_with_parameters",
        code: <<~PATLANG
          goal solve_equation(a, b, c) {
            precondition: a != 0,
            postcondition: result^2 + b*result + c == 0,
            strategy: quadratic_formula
          }
          
          pursue solve_equation
        PATLANG
      }
    ]
    
    test_cases.each do |test_case|
      begin
        evaluator = Evaluator.new
        evaluator.enable_object_mode
        reasoning_coordinator = ReasoningCoordinator.new(evaluator)
        evaluator.set_reasoning_coordinator(reasoning_coordinator)
        
        # Enable reasoning mode
        reasoning_coordinator.enable_reasoning_mode
        
        parser = Parser.new(Lexer.new(test_case[:code]))
        ast = parser.parse
        result = evaluator.evaluate(ast)
        
        puts "✓ #{test_case[:name]} executed successfully"
        
      rescue => e
        if e.message.include?("Undefined variable")
          @error_count += 1
          @errors_found << "#{test_case[:name]}: #{e.message}"
          puts "✗ Found undefined variable error in #{test_case[:name]}: #{e.message}"
        else
          puts "✗ Other error in #{test_case[:name]}: #{e.message}"
        end
      end
    end
  end
end

if __FILE__ == $0
  validator = UndefinedVariableErrorValidator.new
  error_count = validator.run_validation
  puts "\nValidation complete. Found #{error_count} undefined variable errors."
  exit error_count
end