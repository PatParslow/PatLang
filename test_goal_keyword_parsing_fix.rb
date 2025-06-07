#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/reasoning/goal_system'

def test_goal_keyword_parsing_before_fix
  puts "=== Testing Goal Keyword Parsing - BEFORE FIX ==="
  
  # Test the parser's current capability
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
    puts "Tokens generated successfully"
    
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "AST parsed successfully"
    
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    puts "Evaluation completed"
    
  rescue => e
    puts "ERROR: #{e.message}"
    puts "Error class: #{e.class}"
    puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
  end
end

def test_goal_system_integration_before_fix
  puts "\n=== Testing Goal System Integration - BEFORE FIX ==="
  
  begin
    evaluator = Evaluator.new
    goal_system = GoalSystem.new(evaluator)
    
    # Try to declare a goal with all keywords
    definition = <<~DEF
      goal solve_problem {
        description: "Find the optimal solution"
        postcondition: result > 0
        strategies: [breadth_first, depth_first]
        subgoals: [analyze, optimize]
        context: {domain: "math", difficulty: "hard"}
      }
    DEF
    
    goal = goal_system.declare_goal("solve_problem", definition)
    puts "Goal declared successfully: #{goal.name}"
    
  rescue => e
    puts "ERROR: #{e.message}"
    puts "Error class: #{e.class}"
  end
end

# Run tests
test_goal_keyword_parsing_before_fix
test_goal_system_integration_before_fix