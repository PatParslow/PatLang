#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/reasoning/goal_system'

def test_goal_keyword_parsing_after_fix
  puts "=== Testing Goal Keyword Parsing - AFTER FIX ==="
  
  # Test the parser's expanded capability
  code = <<~CODE
    goal solve_problem {
      description: "Find the optimal solution",
      postcondition: result > 0,
      strategies: [breadth_first, depth_first],
      subgoals: [analyze, optimize],
      context: {domain: "math", difficulty: "hard"}
    }
  CODE
  
  begin
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    puts "✓ Tokens generated successfully"
    
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "✓ AST parsed successfully"
    
    # Check if the GoalNode has all the expected attributes
    goal_node = ast
    puts "✓ Goal node created: #{goal_node.name}"
    puts "  - Description: #{goal_node.description}"
    puts "  - Strategies: #{goal_node.strategies.inspect}"
    puts "  - Subgoals: #{goal_node.subgoals.inspect}"
    puts "  - Context: #{goal_node.context.inspect}"
    
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    puts "✓ Evaluation completed successfully"
    
  rescue => e
    puts "ERROR: #{e.message}"
    puts "Error class: #{e.class}"
    puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
  end
end

def test_goal_system_integration_after_fix
  puts "\n=== Testing Goal System Integration - AFTER FIX ==="
  
  begin
    evaluator = Evaluator.new
    goal_system = GoalSystem.new(evaluator)
    evaluator.set_goal_system(goal_system)
    
    # Test parsing with the enhanced parser
    code = <<~CODE
      goal solve_problem {
        description: "Find the optimal solution",
        postcondition: result > 0,
        strategies: [breadth_first, depth_first],
        subgoals: [analyze, optimize],
        context: {domain: "math", difficulty: "hard"}
      }
    CODE
    
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    puts "✓ Goal processed through full integration successfully"
    puts "✓ Goal name: #{result.name}"
    puts "✓ Goal description: #{result.description}"
    puts "✓ Goal strategies: #{result.strategies.inspect}"
    puts "✓ Goal subgoals: #{result.subgoals.inspect}"
    puts "✓ Goal context: #{result.context.inspect}"
    
  rescue => e
    puts "ERROR: #{e.message}"
    puts "Error class: #{e.class}"
    puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
  end
end

def test_error_elimination
  puts "\n=== Testing ArgumentError Elimination ==="
  
  error_keywords = [:postcondition, :description, :strategies, :subgoals, :context]
  errors_eliminated = 0
  
  error_keywords.each do |keyword|
    begin
      code = <<~CODE
        goal test_goal {
          #{keyword}: "test_value"
        }
      CODE
      
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      
      evaluator = Evaluator.new
      result = evaluator.evaluate(ast)
      
      puts "✓ #{keyword} keyword processed successfully"
      errors_eliminated += 1
      
    rescue => e
      puts "✗ #{keyword} keyword still causes error: #{e.message}"
    end
  end
  
  puts "\n=== SUMMARY ==="
  puts "Errors eliminated: #{errors_eliminated}/#{error_keywords.length}"
  puts "Success rate: #{(errors_eliminated.to_f / error_keywords.length * 100).round(1)}%"
  
  if errors_eliminated == error_keywords.length
    puts "🎉 ALL GOAL KEYWORD ARGUMENT ERRORS ELIMINATED!"
  end
end

# Run tests
test_goal_keyword_parsing_after_fix
test_goal_system_integration_after_fix
test_error_elimination