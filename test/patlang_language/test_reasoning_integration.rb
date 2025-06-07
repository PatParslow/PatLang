# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/evaluator'
require_relative '../../src/parser'
require_relative '../../src/lexer'
require_relative '../../src/reasoning/reasoning_coordinator'

# Test end-to-end reasoning syntax and integration with Patlang language
class TestReasoningIntegration < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    @evaluator.enable_object_mode
    @reasoning_coordinator = ReasoningCoordinator.new(@evaluator)
    @evaluator.set_reasoning_coordinator(@reasoning_coordinator)
    @event_log = []
    
    # Subscribe to reasoning events
    @reasoning_coordinator.on_event(:reasoning_mode_enabled) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:constraint_declared) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:goal_created) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:inference_completed) { |e| @event_log << e }
  end

  # === Basic Reasoning Mode Tests ===

  def test_enable_reasoning_mode
    code = "reasoning mode on"
    result = evaluate_patlang_code(code)
    
    assert @reasoning_coordinator.reasoning_mode_enabled?, "Reasoning mode should be enabled"
    assert_events_include :reasoning_mode_enabled
    assert_equal "Reasoning mode enabled", result
  end

  def test_disable_reasoning_mode
    @reasoning_coordinator.enable_reasoning_mode
    
    code = "reasoning mode off"
    result = evaluate_patlang_code(code)
    
    refute @reasoning_coordinator.reasoning_mode_enabled?, "Reasoning mode should be disabled"
    assert_equal "Reasoning mode disabled", result
  end

  # === Type Constraint Syntax Tests ===

  def test_basic_type_constraint_declaration
    enable_reasoning_mode
    code = "constrain x :: Number"
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of TypeConstraint, result
    assert_equal :x, result.variable
    assert_equal :type, result.constraint_type
    assert_equal :Number, result.constraint_data
    assert_events_include :constraint_declared
  end

  def test_constraint_with_range_condition
    enable_reasoning_mode
    code = <<~PATLANG
      constrain age :: Number where age >= 0 and age <= 150
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of TypeConstraint, result
    assert_equal :age, result.variable
    assert result.has_condition?, "Should have range condition"
    
    # Test constraint validation
    assert result.satisfies?(25), "25 should satisfy age constraint"
    refute result.satisfies?(-5), "-5 should not satisfy age constraint"
    refute result.satisfies?(200), "200 should not satisfy age constraint"
  end

  def test_structural_type_constraint
    enable_reasoning_mode
    code = <<~PATLANG
      constrain person :: Object {
        name :: String,
        age :: Number where age >= 0,
        email :: String where email matches /\\w+@\\w+\\.\\w+/
      }
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of TypeConstraint, result
    assert_equal :structural, result.constraint_type
    
    # Test structural validation
    valid_person = {
      name: "John Doe",
      age: 30,
      email: "john@example.com"
    }
    
    invalid_person = {
      name: "Jane",
      age: -5,  # Invalid age
      email: "invalid-email"  # Invalid format
    }
    
    assert result.satisfies?(valid_person), "Valid person should satisfy constraint"
    refute result.satisfies?(invalid_person), "Invalid person should not satisfy constraint"
  end

  def test_constraint_violation_provides_helpful_error
    enable_reasoning_mode
    code = <<~PATLANG
      constrain x :: Number where x > 0
      x = -5
    PATLANG
    
    error = assert_raises(TypeConstraintViolation) do
      evaluate_patlang_code(code)
    end
    
    assert_equal :x, error.variable
    assert_includes error.message, "x > 0"
    assert_equal(-5, error.value)
  end

  # === Goal-Oriented Programming Syntax Tests ===

  def test_basic_goal_declaration
    enable_reasoning_mode
    code = <<~PATLANG
      goal find_answer {
        postcondition: answer > 0 and answer < 100
      }
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of Goal, result
    assert_equal "find_answer", result.name
    assert result.has_postcondition?, "Should have postcondition"
    assert_events_include :goal_created
  end

  def test_goal_with_preconditions_and_strategy
    enable_reasoning_mode
    code = <<~PATLANG
      goal solve_equation(a, b, c) {
        precondition: a != 0,
        postcondition: result^2 + b*result + c == 0,
        strategy: quadratic_formula
      }
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of Goal, result
    assert_equal "solve_equation", result.name
    assert_equal [:a, :b, :c], result.parameters
    assert result.has_precondition?, "Should have precondition"
    assert result.has_postcondition?, "Should have postcondition"
    assert_equal :quadratic_formula, result.strategy
  end

  def test_goal_pursuit_with_simple_strategy
    enable_reasoning_mode
    code = <<~PATLANG
      goal find_even {
        postcondition: result.even? and result > 10
      }
      
      pursue find_even
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert result.is_a?(Numeric), "Should return a number"
    assert result.even?, "Result should be even"
    assert_operator result, :>, 10, "Result should be greater than 10"
  end

  # === Logic Programming Syntax Tests ===

  def test_fact_assertion
    enable_reasoning_mode
    code = <<~PATLANG
      assert fact(likes(alice, bob))
      assert fact(likes(bob, charlie))
      assert fact(parent(alice, bob))
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    facts = @reasoning_coordinator.get_facts
    assert_includes facts, "likes(alice, bob)"
    assert_includes facts, "likes(bob, charlie)"
    assert_includes facts, "parent(alice, bob)"
    assert_equal "3 facts asserted", result
  end

  def test_rule_definition
    enable_reasoning_mode
    code = <<~PATLANG
      rule ancestor(X, Y) :-
        parent(X, Y).
      
      rule ancestor(X, Z) :-
        parent(X, Y),
        ancestor(Y, Z).
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    rules = @reasoning_coordinator.get_rules
    assert rules.any? { |r| r.head.functor == "ancestor" }, "Should have ancestor rule"
    assert_equal "2 rules defined", result
  end

  def test_query_execution
    enable_reasoning_mode
    setup_family_facts
    
    code = "query likes(alice, Who)"
    result = evaluate_patlang_code(code)
    
    assert_instance_of Array, result
    assert_includes result, { Who: "bob" }
  end

  def test_complex_query_with_variables
    enable_reasoning_mode
    setup_family_facts
    
    code = <<~PATLANG
      query likes(X, Y) and parent(X, Y)
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of Array, result
    assert result.any? { |binding| binding[:X] == "alice" && binding[:Y] == "bob" }
  end

  # === Cross-Paradigm Integration Tests ===

  def test_type_guided_goal_resolution
    enable_reasoning_mode
    code = <<~PATLANG
      constrain x :: Number where x > 0 and x < 100
      
      goal find_valid_x {
        postcondition: x.even? and x % 3 == 0
      }
      
      result = pursue find_valid_x
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert result.is_a?(Numeric), "Should return a number"
    assert_operator result, :>, 0, "Should satisfy lower bound"
    assert_operator result, :<, 100, "Should satisfy upper bound"
    assert result.even?, "Should be even"
    assert_equal 0, result % 3, "Should be divisible by 3"
  end

  def test_logic_enhanced_type_checking
    enable_reasoning_mode
    code = <<~PATLANG
      assert fact(typeof(x, number))
      assert fact(range(number, 1, 100))
      assert fact(property(x, positive))
      
      constrain x :: infer_from_facts
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    assert_instance_of TypeConstraint, result
    constraint = @reasoning_coordinator.get_constraint(:x)
    assert constraint.satisfies?(50), "Should accept valid number"
    refute constraint.satisfies?(-5), "Should reject negative number"
    refute constraint.satisfies?("string"), "Should reject non-number"
  end

  def test_goal_driven_fact_discovery
    enable_reasoning_mode
    code = <<~PATLANG
      goal discover_relationships {
        postcondition: knows(alice, Someone) and friend(Someone, alice)
      }
      
      # Initial facts
      assert fact(knows(alice, bob))
      assert fact(knows(bob, charlie))
      
      # Rules for friendship
      rule friend(X, Y) :- knows(X, Y), knows(Y, X).
      
      result = pursue discover_relationships
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    # Goal pursuit should have discovered or asserted additional facts
    facts = @reasoning_coordinator.get_facts
    assert facts.any? { |f| f.include?("friend") }, "Should have discovered friendship facts"
  end

  # === Error Handling and Edge Cases ===

  def test_reasoning_mode_required_for_constraints
    # Don't enable reasoning mode
    code = "constrain x :: Number"
    
    error = assert_raises(ReasoningModeError) do
      evaluate_patlang_code(code)
    end
    
    assert_includes error.message, "reasoning mode"
    assert_includes error.message, "constrain"
  end

  def test_invalid_constraint_syntax_reports_error
    enable_reasoning_mode
    code = "constrain x :: InvalidType"
    
    error = assert_raises(ParseError) do
      evaluate_patlang_code(code)
    end
    
    assert_includes error.message, "InvalidType"
    assert_includes error.message, "constraint"
  end

  def test_malformed_goal_syntax_reports_location
    enable_reasoning_mode
    code = <<~PATLANG
      goal malformed {
        postcondition missing colon
      }
    PATLANG
    
    error = assert_raises(ParseError) do
      evaluate_patlang_code(code)
    end
    
    assert error.respond_to?(:line), "Error should include line information"
    assert error.respond_to?(:column), "Error should include column information"
  end

  def test_undefined_predicate_in_query
    enable_reasoning_mode
    code = "query undefined_predicate(X)"
    
    error = assert_raises(LogicError) do
      evaluate_patlang_code(code)
    end
    
    assert_includes error.message, "undefined_predicate"
    assert_includes error.message, "not defined"
  end

  # === Integration with Object Mode ===

  def test_reasoning_with_object_mode_variables
    enable_reasoning_mode
    code = <<~PATLANG
      obj = Object.new
      obj.value = 42
      
      constrain obj.value :: Number where value > 0
      
      goal optimize(obj) {
        postcondition: obj.value % 7 == 0 and obj.value < 100
      }
      
      pursue optimize(obj)
    PATLANG
    
    result = evaluate_patlang_code(code)
    
    # Should have modified obj.value to satisfy the goal
    assert_operator result, :>, 0, "Should be positive"
    assert_equal 0, result % 7, "Should be divisible by 7"
    assert_operator result, :<, 100, "Should be less than 100"
  end

  def test_constraint_violation_in_object_mode
    enable_reasoning_mode
    code = <<~PATLANG
      obj = Object.new
      constrain obj.value :: Number where value >= 0
      obj.value = -5
    PATLANG
    
    error = assert_raises(TypeConstraintViolation) do
      evaluate_patlang_code(code)
    end
    
    assert_includes error.message, "obj.value"
    assert_equal(-5, error.value)
  end

  # === Performance and Stress Tests ===

  def test_constraint_evaluation_performance_acceptable
    enable_reasoning_mode
    
    # Create multiple constraints
    constraints_code = (1..100).map do |i|
      "constrain x#{i} :: Number where x#{i} >= 0 and x#{i} <= 1000"
    end.join("\n")
    
    start_time = Time.now
    evaluate_patlang_code(constraints_code)
    duration = Time.now - start_time
    
    assert_operator duration, :<, 1.0, "100 constraint declarations should complete in <1 second"
  end

  def test_goal_resolution_with_backtracking_performance
    enable_reasoning_mode
    code = <<~PATLANG
      goal complex_search {
        postcondition: result > 50 and result < 60 and result.prime?
      }
      
      result = pursue complex_search
    PATLANG
    
    start_time = Time.now
    result = evaluate_patlang_code(code)
    duration = Time.now - start_time
    
    assert_operator duration, :<, 0.5, "Complex goal resolution should complete reasonably quickly"
    assert result.is_a?(Numeric), "Should find a valid result"
  end

  def test_large_fact_database_query_performance
    enable_reasoning_mode
    
    # Assert many facts
    facts_code = (1..1000).map do |i|
      "assert fact(number(#{i}))"
    end.join("\n")
    
    query_code = "query number(X) where X > 500 and X < 600"
    
    evaluate_patlang_code(facts_code)
    
    start_time = Time.now
    result = evaluate_patlang_code(query_code)
    duration = Time.now - start_time
    
    assert_operator duration, :<, 0.1, "Query over 1000 facts should be fast"
    assert_instance_of Array, result
    assert_equal 99, result.length, "Should find 99 numbers between 500 and 600"
  end

  private

  def evaluate_patlang_code(code)
    parser = Parser.new(Lexer.new(code))
    ast = parser.parse
    @evaluator.evaluate(ast)
  rescue => e
    # Re-raise with better context for debugging
    raise e.class, "Error evaluating: #{code.inspect}\nOriginal: #{e.message}", e.backtrace
  end

  def enable_reasoning_mode
    @reasoning_coordinator.enable_reasoning_mode
  end

  def setup_family_facts
    facts_code = <<~PATLANG
      assert fact(likes(alice, bob))
      assert fact(likes(bob, charlie))
      assert fact(parent(alice, bob))
      assert fact(parent(bob, charlie))
    PATLANG
    
    evaluate_patlang_code(facts_code)
  end

  def assert_events_include(event_type)
    event_types = @event_log.map { |e| e[:event_type] }
    assert_includes event_types, event_type, "Expected #{event_type} event to be fired"
  end
end

# Removed duplicate class definitions - using actual implementations from src/