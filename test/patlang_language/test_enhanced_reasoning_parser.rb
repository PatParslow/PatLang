# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/parser'
require_relative '../../src/lexer'
require_relative '../../src/ast_nodes'

# Test enhanced reasoning parser integration with advanced syntax support
class TestEnhancedReasoningParser < Minitest::Test
  def setup
    @parser_timeout = 5.0  # Timeout for parsing operations
  end

  # === Enhanced Constraint Parsing Tests ===

  def test_basic_type_constraint_parsing
    code = "constrain x :: Number"
    ast = parse_code(code)
    
    assert_instance_of TypeConstraintNode, ast
    assert_equal :x, ast.variable
    assert_equal :Number, ast.constraint_type
  end

  def test_dotted_constraint_parsing
    code = "constrain user.age :: Number"
    ast = parse_code(code)
    
    assert_instance_of TypeConstraintNode, ast
    assert_equal "user.age", ast.variable
    assert_equal :Number, ast.constraint_type
  end

  def test_constraint_with_conditions
    code = "constrain age :: Number where age >= 0 and age <= 150"
    ast = parse_code(code)
    
    assert_instance_of TypeConstraintNode, ast
    assert_equal :age, ast.variable
    assert_equal :Number, ast.constraint_type
    refute_nil ast.conditions
  end

  def test_structural_constraint_parsing
    code = "constrain person :: Object { name :: String, age :: Number }"
    ast = parse_code(code)
    
    # Should parse successfully (might be BlockNode or StructuralConstraintNode)
    refute_instance_of ErrorNode, ast
  end

  def test_array_constraint_parsing
    code = "constrain items :: Array[Number]"
    ast = parse_code(code)
    
    # Should parse successfully
    refute_instance_of ErrorNode, ast
  end

  # === Enhanced Goal Parsing Tests ===

  def test_simple_goal_parsing
    code = "goal find_answer { postcondition: answer > 0 }"
    ast = parse_code(code)
    
    assert_instance_of GoalNode, ast
    assert_equal "find_answer", ast.description
  end

  def test_goal_with_parameters
    code = "goal solve_equation(a, b, c) { precondition: a != 0 }"
    ast = parse_code(code)
    
    assert_instance_of GoalNode, ast
    assert_equal "solve_equation", ast.description
  end

  def test_goal_with_typed_parameters
    code = "goal process_data(input :: Array, threshold :: Number) { postcondition: result.length > 0 }"
    ast = parse_code(code)
    
    assert_instance_of GoalNode, ast
    assert_equal "process_data", ast.description
  end

  def test_goal_with_strategies
    code = 'goal optimize { strategies: ["heuristic", "brute_force"] }'
    ast = parse_code(code)
    
    assert_instance_of GoalNode, ast
    assert_equal "optimize", ast.description
  end

  def test_goal_with_metadata
    code = "goal complex_task { timeout: 30, priority: 5, postcondition: result.valid? }"
    ast = parse_code(code)
    
    assert_instance_of GoalNode, ast
    assert_equal "complex_task", ast.description
  end

  # === Enhanced Logic Programming Tests ===

  def test_fact_declaration
    code = "fact parent(john, mary)"
    ast = parse_code(code)
    
    assert_instance_of LogicRuleNode, ast
    assert_equal :fact, ast.rule_type
  end

  def test_rule_with_if_syntax
    code = "rule ancestor(X, Z) if parent(X, Y) and ancestor(Y, Z)"
    ast = parse_code(code)
    
    assert_instance_of LogicRuleNode, ast
    assert_equal :standard, ast.rule_type
  end

  def test_rule_with_prolog_syntax
    code = "rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z)"
    ast = parse_code(code)
    
    assert_instance_of LogicRuleNode, ast
  end

  def test_complex_rule_body
    code = "rule eligible(Person) if employee(Person, Dept, Salary) and Salary > 50000 and experience(Person, Years) and Years >= 2"
    ast = parse_code(code)
    
    assert_instance_of LogicRuleNode, ast
    refute_nil ast.body
  end

  # === Query Parsing Tests ===

  def test_basic_query
    code = "query parent(X, mary)"
    ast = parse_code(code)
    
    assert_instance_of QueryNode, ast
    assert_equal :standard, ast.query_type
  end

  def test_prolog_style_query
    code = "?- parent(john, X)"
    ast = parse_code(code)
    
    assert_instance_of QueryNode, ast
    assert_equal :prolog, ast.query_type
    assert_includes ast.variables, :X
  end

  def test_complex_query
    code = "query employee(Person, Dept, Salary) and Salary > 70000"
    ast = parse_code(code)
    
    assert_instance_of QueryNode, ast
  end

  # === Pursuit and Control Tests ===

  def test_simple_pursue
    code = "pursue find_answer"
    ast = parse_code(code)
    
    assert_instance_of PursueNode, ast
    assert_equal "find_answer", ast.goal_name
  end

  def test_pursue_with_arguments
    code = "pursue solve_equation(1, 2, 3)"
    ast = parse_code(code)
    
    assert_instance_of PursueNode, ast
    assert_equal "solve_equation", ast.goal_name
    assert_equal 3, ast.arguments.length
  end

  def test_reasoning_mode_control
    # Test reasoning mode on
    code_on = "reasoning mode on"
    ast_on = parse_code(code_on)
    
    assert_instance_of ReasoningModeNode, ast_on
    assert_equal true, ast_on.enabled
    
    # Test reasoning mode off
    code_off = "reasoning mode off"
    ast_off = parse_code(code_off)
    
    assert_instance_of ReasoningModeNode, ast_off
    assert_equal false, ast_off.enabled
  end

  # === Type Annotation Tests ===

  def test_type_annotation
    code = "x :: Number"
    ast = parse_code(code)
    
    assert_instance_of TypeAnnotationNode, ast
    assert_equal "x", ast.variable_name
  end

  def test_typed_assignment
    code = "x: Number = 42"
    ast = parse_code(code)
    
    # Should parse successfully (might be TypedAssignmentNode or similar)
    refute_instance_of ErrorNode, ast
  end

  # === Integration and Complex Syntax Tests ===

  def test_multiple_statements
    code = <<~PATLANG
      reasoning mode on
      constrain x :: Number
      goal find_positive { postcondition: x > 0 }
      pursue find_positive
    PATLANG
    
    ast = parse_code(code)
    
    # Should parse as a block of statements
    refute_instance_of ErrorNode, ast
  end

  def test_nested_complex_syntax
    code = <<~PATLANG
      goal complex_optimization(data :: Array[Number]) {
        precondition: data.length > 0,
        postcondition: result.score > 0.8 and result.valid?,
        strategies: ["genetic_algorithm", "simulated_annealing"],
        timeout: 60
      }
    PATLANG
    
    ast = parse_code(code)
    
    assert_instance_of GoalNode, ast
    assert_equal "complex_optimization", ast.description
  end

  def test_cross_paradigm_syntax
    code = <<~PATLANG
      constrain user :: Object { name :: String, age :: Number }
      rule adult(Person) if user(Person) and Person.age >= 18
      goal validate_user(user_data) {
        precondition: user_data :: Object,
        postcondition: adult(result)
      }
    PATLANG
    
    ast = parse_code(code)
    
    # Should parse successfully as a block
    refute_instance_of ErrorNode, ast
  end

  # === Error Handling and Edge Cases ===

  def test_malformed_constraint_syntax
    code = "constrain x ::: InvalidSyntax"
    
    # Should handle gracefully (might return ErrorNode or throw exception)
    assert_nothing_raised do
      ast = parse_code(code)
      # Verify it doesn't crash the parser
      refute_nil ast
    end
  end

  def test_incomplete_goal_syntax
    code = "goal incomplete_goal {"
    
    # Should handle gracefully
    assert_nothing_raised do
      ast = parse_code(code)
      refute_nil ast
    end
  end

  def test_invalid_rule_syntax
    code = "rule invalid_rule without_proper_syntax"
    
    # Should handle gracefully
    assert_nothing_raised do
      ast = parse_code(code)
      refute_nil ast
    end
  end

  # === Performance and Stress Tests ===

  def test_large_constraint_declaration
    constraints = (1..100).map do |i|
      "constrain var#{i} :: Number where var#{i} >= 0"
    end.join("\n")
    
    start_time = Time.now
    ast = parse_code(constraints)
    duration = Time.now - start_time
    
    assert_operator duration, :<, 2.0, "Large constraint parsing should complete in reasonable time"
    refute_instance_of ErrorNode, ast
  end

  def test_complex_rule_parsing_performance
    rules = (1..50).map do |i|
      "rule complex_rule_#{i}(X, Y, Z) if predicate#{i}(X, Y) and condition#{i}(Y, Z) and validation#{i}(Z)"
    end.join("\n")
    
    start_time = Time.now
    ast = parse_code(rules)
    duration = Time.now - start_time
    
    assert_operator duration, :<, 1.0, "Complex rule parsing should be efficient"
    refute_instance_of ErrorNode, ast
  end

  private

  def parse_code(code)
    lexer = Lexer.new(code)
    parser = Parser.new(lexer)
    
    # Apply timeout protection
    result = nil
    timeout_thread = Thread.new do
      sleep @parser_timeout
      Thread.main.raise TimeoutError, "Parser test exceeded #{@parser_timeout}s timeout"
    end
    
    begin
      result = parser.parse
    ensure
      timeout_thread.kill
    end
    
    result
  rescue => e
    # Return error information for debugging
    ErrorNode.new("Parse error: #{e.message}")
  end
end