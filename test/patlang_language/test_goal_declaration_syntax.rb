# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/goal_system'
require_relative '../../src/reasoning/reasoning_coordinator'

# Comprehensive tests for goal declaration syntax and semantics in the Patlang language
class TestGoalDeclarationSyntax < Minitest::Test
  def setup
    @evaluator = MockEvaluator.new
    @goal_system = GoalSystem.new(@evaluator)
    @reasoning_coordinator = ReasoningCoordinator.new(@evaluator)
    @goal_system.set_reasoning_coordinator(@reasoning_coordinator)
    @reasoning_coordinator.enable_reasoning_mode
    @event_log = []
    
    # Subscribe to goal events
    @goal_system.on_event(:goal_declared) { |e| @event_log << e }
    @goal_system.on_event(:goal_pursued) { |e| @event_log << e }
    @goal_system.on_event(:goal_achieved) { |e| @event_log << e }
    @goal_system.on_event(:goal_failed) { |e| @event_log << e }
  end

  # === Basic Goal Declaration Syntax Tests ===

  def test_minimal_goal_declaration_syntax
    goal_definition = <<~GOAL
      goal simple_goal {
        description: "A simple goal with minimal syntax"
      }
    GOAL
    
    goal = @goal_system.declare_goal(:simple_goal, goal_definition)
    
    assert_instance_of Goal, goal
    assert_equal :simple_goal, goal.name
    assert_equal "A simple goal with minimal syntax", goal.description
    refute goal.has_precondition?
    refute goal.has_postcondition?
    refute goal.has_subgoals?
    refute goal.has_multiple_strategies?
  end

  def test_empty_goal_declaration_syntax
    goal_definition = <<~GOAL
      goal empty_goal {
      }
    GOAL
    
    goal = @goal_system.declare_goal(:empty_goal, goal_definition)
    
    assert_instance_of Goal, goal
    assert_equal :empty_goal, goal.name
    assert_nil goal.description
    assert_empty goal.parameters
    assert_empty goal.preconditions
    assert_empty goal.postconditions
  end

  def test_goal_with_description_syntax
    goal_definition = <<~GOAL
      goal documented_goal {
        description: "This goal demonstrates comprehensive documentation"
      }
    GOAL
    
    goal = @goal_system.declare_goal(:documented_goal, goal_definition)
    
    assert_equal "This goal demonstrates comprehensive documentation", goal.description
  end

  # === Goal Parameters Syntax Tests ===

  def test_goal_with_parameters_syntax
    goal_definition = <<~GOAL
      goal parameterized_goal {
        description: "Goal that accepts parameters"
        parameters: [input, target, tolerance]
      }
    GOAL
    
    goal = @goal_system.declare_goal(:parameterized_goal, goal_definition)
    
    expected_params = [:input, :target, :tolerance]
    assert_equal expected_params, goal.parameters
  end

  def test_goal_with_single_parameter_syntax
    goal_definition = <<~GOAL
      goal single_param_goal {
        description: "Goal with one parameter"
        parameters: [value]
      }
    GOAL
    
    goal = @goal_system.declare_goal(:single_param_goal, goal_definition)
    
    assert_equal [:value], goal.parameters
  end

  def test_goal_with_no_explicit_parameters_syntax
    goal_definition = <<~GOAL
      goal no_params_goal {
        description: "Goal without explicit parameters"
      }
    GOAL
    
    goal = @goal_system.declare_goal(:no_params_goal, goal_definition)
    
    assert_empty goal.parameters
  end

  # === Precondition Syntax Tests ===

  def test_single_precondition_syntax
    goal_definition = <<~GOAL
      goal conditional_goal {
        description: "Goal with a single precondition"
        precondition: input != null
      }
    GOAL
    
    goal = @goal_system.declare_goal(:conditional_goal, goal_definition)
    
    assert goal.has_precondition?
    assert_equal ["input != null"], goal.preconditions
  end

  def test_multiple_preconditions_syntax
    goal_definition = <<~GOAL
      goal multi_precondition_goal {
        description: "Goal with multiple preconditions"
        precondition: a > 0,
        precondition: b > 0,
        precondition: a != b
      }
    GOAL
    
    goal = @goal_system.declare_goal(:multi_precondition_goal, goal_definition)
    
    assert goal.has_precondition?
    expected_preconditions = ["a > 0", "b > 0", "a != b"]
    assert_equal expected_preconditions, goal.preconditions
  end

  def test_complex_precondition_syntax
    goal_definition = <<~GOAL
      goal complex_precondition_goal {
        description: "Goal with complex precondition logic"
        precondition: (x > 0 and x < 100) or (x > 200 and x < 300)
      }
    GOAL
    
    goal = @goal_system.declare_goal(:complex_precondition_goal, goal_definition)
    
    assert goal.has_precondition?
    assert_equal ["(x > 0 and x < 100) or (x > 200 and x < 300)"], goal.preconditions
  end

  # === Postcondition Syntax Tests ===

  def test_single_postcondition_syntax
    goal_definition = <<~GOAL
      goal result_goal {
        description: "Goal with a single postcondition"
        postcondition: result > 0
      }
    GOAL
    
    goal = @goal_system.declare_goal(:result_goal, goal_definition)
    
    assert goal.has_postcondition?
    assert_equal ["result > 0"], goal.postconditions
  end

  def test_multiple_postconditions_syntax
    goal_definition = <<~GOAL
      goal validated_goal {
        description: "Goal with multiple postconditions"
        postcondition: result.is_a?(Number),
        postcondition: result > 10,
        postcondition: result < 100
      }
    GOAL
    
    goal = @goal_system.declare_goal(:validated_goal, goal_definition)
    
    assert goal.has_postcondition?
    expected_postconditions = ["result.is_a?(Number)", "result > 10", "result < 100"]
    assert_equal expected_postconditions, goal.postconditions
  end

  def test_complex_postcondition_syntax
    goal_definition = <<~GOAL
      goal complex_result_goal {
        description: "Goal with complex postcondition validation"
        postcondition: result.even? and result > 20 and result < 30
      }
    GOAL
    
    goal = @goal_system.declare_goal(:complex_result_goal, goal_definition)
    
    assert goal.has_postcondition?
    assert_equal ["result.even? and result > 20 and result < 30"], goal.postconditions
  end

  # === Strategy Declaration Syntax Tests ===

  def test_single_strategy_syntax
    goal_definition = <<~GOAL
      goal strategic_goal {
        description: "Goal with a specific strategy"
        strategy: binary_search
      }
    GOAL
    
    goal = @goal_system.declare_goal(:strategic_goal, goal_definition)
    
    assert_equal :binary_search, goal.strategy
    refute goal.has_multiple_strategies?
  end

  def test_multiple_strategies_syntax
    goal_definition = <<~GOAL
      goal flexible_goal {
        description: "Goal with multiple strategy options"
        strategies: [linear_search, binary_search, hash_lookup, tree_traversal]
      }
    GOAL
    
    goal = @goal_system.declare_goal(:flexible_goal, goal_definition)
    
    expected_strategies = [:linear_search, :binary_search, :hash_lookup, :tree_traversal]
    assert_equal expected_strategies, goal.strategies
    assert goal.has_multiple_strategies?
  end

  def test_strategy_with_preference_syntax
    goal_definition = <<~GOAL
      goal optimized_goal {
        description: "Goal with strategy preference"
        strategies: [brute_force, heuristic, optimal]
        preference: fastest
      }
    GOAL
    
    goal = @goal_system.declare_goal(:optimized_goal, goal_definition)
    
    assert_equal [:brute_force, :heuristic, :optimal], goal.strategies
    assert_equal :fastest, goal.preference
  end

  def test_combined_strategy_and_strategies_syntax
    goal_definition = <<~GOAL
      goal combined_strategy_goal {
        description: "Goal with both single strategy and strategy list"
        strategy: default_strategy
        strategies: [strategy_a, strategy_b, strategy_c]
        preference: balanced
      }
    GOAL
    
    goal = @goal_system.declare_goal(:combined_strategy_goal, goal_definition)
    
    assert_equal :default_strategy, goal.strategy
    assert_equal [:strategy_a, :strategy_b, :strategy_c], goal.strategies
    assert_equal :balanced, goal.preference
  end

  # === Subgoal Declaration Syntax Tests ===

  def test_subgoals_syntax
    goal_definition = <<~GOAL
      goal hierarchical_goal {
        description: "Goal composed of multiple subgoals"
        subgoals: [prepare_data, validate_input, process_data, generate_output]
      }
    GOAL
    
    goal = @goal_system.declare_goal(:hierarchical_goal, goal_definition)
    
    assert goal.has_subgoals?
    expected_subgoals = [:prepare_data, :validate_input, :process_data, :generate_output]
    assert_equal expected_subgoals, goal.subgoals
  end

  def test_single_subgoal_syntax
    goal_definition = <<~GOAL
      goal simple_hierarchy_goal {
        description: "Goal with a single subgoal"
        subgoals: [initialize_system]
      }
    GOAL
    
    goal = @goal_system.declare_goal(:simple_hierarchy_goal, goal_definition)
    
    assert goal.has_subgoals?
    assert_equal [:initialize_system], goal.subgoals
  end

  def test_nested_subgoals_syntax
    goal_definition = <<~GOAL
      goal complex_hierarchy_goal {
        description: "Goal with nested subgoal structure"
        subgoals: [setup_phase, execution_phase, cleanup_phase]
        strategy: sequential
      }
    GOAL
    
    goal = @goal_system.declare_goal(:complex_hierarchy_goal, goal_definition)
    
    assert goal.has_subgoals?
    assert_equal [:setup_phase, :execution_phase, :cleanup_phase], goal.subgoals
    assert_equal :sequential, goal.strategy
  end

  # === Context Declaration Syntax Tests ===

  def test_context_syntax
    goal_definition = <<~GOAL
      goal contextual_goal {
        description: "Goal with execution context"
        context: {timeout: 30, max_retries: 3, log_level: debug}
      }
    GOAL
    
    goal = @goal_system.declare_goal(:contextual_goal, goal_definition)
    
    expected_context = { timeout: "30", max_retries: "3", log_level: "debug" }
    assert_equal expected_context, goal.context
  end

  def test_empty_context_syntax
    goal_definition = <<~GOAL
      goal no_context_goal {
        description: "Goal without context"
        context: {}
      }
    GOAL
    
    goal = @goal_system.declare_goal(:no_context_goal, goal_definition)
    
    assert_empty goal.context
  end

  def test_complex_context_syntax
    goal_definition = <<~GOAL
      goal rich_context_goal {
        description: "Goal with rich context information"
        context: {
          database_url: "postgresql://localhost:5432/db",
          cache_enabled: true,
          batch_size: 1000,
          error_threshold: 0.05
        }
      }
    GOAL
    
    goal = @goal_system.declare_goal(:rich_context_goal, goal_definition)
    
    context = goal.context
    assert_equal "postgresql://localhost:5432/db", context[:database_url]
    assert_equal "true", context[:cache_enabled]
    assert_equal "1000", context[:batch_size]
    assert_equal "0.05", context[:error_threshold]
  end

  # === Complete Goal Declaration Syntax Tests ===

  def test_comprehensive_goal_declaration_syntax
    goal_definition = <<~GOAL
      goal comprehensive_goal {
        description: "A goal demonstrating all syntax features"
        parameters: [input_data, validation_rules, output_format]
        precondition: input_data != null
        precondition: validation_rules.length > 0
        postcondition: result.valid?
        postcondition: result.format == output_format
        strategy: adaptive
        strategies: [strict_validation, lenient_validation, custom_validation]
        preference: accuracy
        subgoals: [parse_input, apply_rules, format_output, validate_result]
        context: {
          timeout: 60,
          max_memory: "512MB",
          parallel: true
        }
      }
    GOAL
    
    goal = @goal_system.declare_goal(:comprehensive_goal, goal_definition)
    
    # Validate all components
    assert_equal :comprehensive_goal, goal.name
    assert_equal "A goal demonstrating all syntax features", goal.description
    assert_equal [:input_data, :validation_rules, :output_format], goal.parameters
    
    assert goal.has_precondition?
    assert_includes goal.preconditions, "input_data != null"
    assert_includes goal.preconditions, "validation_rules.length > 0"
    
    assert goal.has_postcondition?
    assert_includes goal.postconditions, "result.valid?"
    assert_includes goal.postconditions, "result.format == output_format"
    
    assert_equal :adaptive, goal.strategy
    assert_equal [:strict_validation, :lenient_validation, :custom_validation], goal.strategies
    assert_equal :accuracy, goal.preference
    
    assert goal.has_subgoals?
    assert_equal [:parse_input, :apply_rules, :format_output, :validate_result], goal.subgoals
    
    refute_empty goal.context
    assert_equal "60", goal.context[:timeout]
    assert_equal "512MB", goal.context[:max_memory]
    assert_equal "true", goal.context[:parallel]
  end

  # === Goal Execution and Resolution Tests ===

  def test_goal_execution_with_preconditions
    goal_definition = <<~GOAL
      goal preconditioned_goal {
        description: "Goal that validates preconditions"
        precondition: a != 0
        postcondition: result > 10 and result < 100 and result.even?
      }
    GOAL
    
    @goal_system.declare_goal(:preconditioned_goal, goal_definition)
    
    # Should succeed with valid precondition
    result = @goal_system.pursue_goal(:preconditioned_goal, a: 5)
    assert_instance_of Integer, result
    assert result > 10
    assert result < 100
    assert result.even?
    
    # Should fail with invalid precondition
    error = assert_raises(RuntimeError) do
      @goal_system.pursue_goal(:preconditioned_goal, a: 0)
    end
    assert_includes error.message, "Preconditions not satisfied"
  end

  def test_goal_execution_with_postconditions
    goal_definition = <<~GOAL
      goal strict_postcondition_goal {
        description: "Goal with strict result validation"
        postcondition: result.even? and result > 20 and result < 30
      }
    GOAL
    
    @goal_system.declare_goal(:strict_postcondition_goal, goal_definition)
    
    result = @goal_system.pursue_goal(:strict_postcondition_goal)
    
    # Validate postconditions are met
    assert_instance_of Integer, result
    assert result.even?
    assert result > 20
    assert result < 30
  end

  def test_goal_execution_with_context
    goal_definition = <<~GOAL
      goal contextual_execution_goal {
        description: "Goal that uses execution context"
        context: {default_value: 42, multiplier: 2}
      }
    GOAL
    
    @goal_system.declare_goal(:contextual_execution_goal, goal_definition)
    
    result = @goal_system.pursue_goal(:contextual_execution_goal)
    
    # Should execute successfully (exact result depends on implementation)
    assert_instance_of Integer, result
  end

  # === Goal Declaration Event Tests ===

  def test_goal_declaration_fires_events
    goal_definition = <<~GOAL
      goal event_test_goal {
        description: "Goal for testing event generation"
      }
    GOAL
    
    goal = @goal_system.declare_goal(:event_test_goal, goal_definition)
    
    # Check that declaration event was fired
    declaration_events = @event_log.select { |e| e[:event_type] == :goal_declared }
    assert declaration_events.any?
    
    declaration_event = declaration_events.first
    assert_equal :event_test_goal, declaration_event[:name]
    assert_equal goal, declaration_event[:goal]
    assert_instance_of Time, declaration_event[:timestamp]
  end

  def test_goal_pursuit_fires_events
    goal_definition = <<~GOAL
      goal pursuit_test_goal {
        description: "Goal for testing pursuit events"
      }
    GOAL
    
    @goal_system.declare_goal(:pursuit_test_goal, goal_definition)
    @goal_system.pursue_goal(:pursuit_test_goal)
    
    # Check pursuit events
    pursuit_events = @event_log.select { |e| e[:event_type] == :goal_pursued }
    assert pursuit_events.any?
    
    achievement_events = @event_log.select { |e| e[:event_type] == :goal_achieved }
    assert achievement_events.any?
  end

  # === Error Handling and Malformed Syntax Tests ===

  def test_malformed_goal_definition_handling
    malformed_definition = "this is not valid goal syntax"
    
    goal = @goal_system.declare_goal(:malformed_goal, malformed_definition)
    
    # Should still create a goal but with minimal parsed content
    assert_instance_of Goal, goal
    assert_equal :malformed_goal, goal.name
  end

  def test_partially_malformed_goal_definition
    partially_malformed = <<~GOAL
      goal partial_goal {
        description: "Valid description"
        invalid_field: this_should_be_ignored
        postcondition: result > 0
      }
    GOAL
    
    goal = @goal_system.declare_goal(:partial_goal, partially_malformed)
    
    # Valid parts should be parsed correctly
    assert_equal "Valid description", goal.description
    assert goal.has_postcondition?
    assert_includes goal.postconditions, "result > 0"
  end

  def test_empty_goal_definition_handling
    empty_definition = ""
    
    goal = @goal_system.declare_goal(:empty_def_goal, empty_definition)
    
    assert_instance_of Goal, goal
    assert_equal :empty_def_goal, goal.name
    refute goal.has_precondition?
    refute goal.has_postcondition?
  end

  # === Performance Tests ===

  def test_goal_declaration_performance
    start_time = Time.now
    
    50.times do |i|
      goal_definition = <<~GOAL
        goal performance_goal_#{i} {
          description: "Performance test goal #{i}"
          precondition: input > 0
          postcondition: result.even?
          strategy: optimized
        }
      GOAL
      
      @goal_system.declare_goal("performance_goal_#{i}".to_sym, goal_definition)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.5, "50 goal declarations should complete in <500ms"
  end

  def test_complex_goal_declaration_performance
    complex_definition = <<~GOAL
      goal complex_performance_goal {
        description: "Complex goal for performance testing"
        parameters: [a, b, c, d, e, f, g, h, i, j]
        precondition: a > 0
        precondition: b > 0
        precondition: c > 0
        postcondition: result.is_a?(Number)
        postcondition: result > 0
        postcondition: result < 1000
        strategy: adaptive
        strategies: [strategy_a, strategy_b, strategy_c, strategy_d, strategy_e]
        preference: optimal
        subgoals: [step_1, step_2, step_3, step_4, step_5]
        context: {
          timeout: 120,
          memory_limit: "1GB",
          cpu_cores: 4,
          cache_size: "256MB",
          log_level: "debug"
        }
      }
    GOAL
    
    start_time = Time.now
    
    10.times do |i|
      @goal_system.declare_goal("complex_goal_#{i}".to_sym, complex_definition)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.2, "10 complex goal declarations should complete in <200ms"
  end

  # === Goal Syntax Validation Tests ===

  def test_goal_name_validation
    # Goal names should be valid symbols/identifiers
    valid_names = [:simple_goal, :goal_123, :CamelCaseGoal, :goal_with_underscores]
    
    valid_names.each do |name|
      goal_definition = <<~GOAL
        goal #{name} {
          description: "Test goal with valid name"
        }
      GOAL
      
      goal = @goal_system.declare_goal(name, goal_definition)
      assert_equal name, goal.name
    end
  end

  def test_goal_retrieval_after_declaration
    goal_definition = <<~GOAL
      goal retrievable_goal {
        description: "Goal that can be retrieved after declaration"
        strategy: test_strategy
      }
    GOAL
    
    declared_goal = @goal_system.declare_goal(:retrievable_goal, goal_definition)
    retrieved_goal = @goal_system.get_goal(:retrievable_goal)
    
    assert_equal declared_goal, retrieved_goal
    assert_equal :retrievable_goal, retrieved_goal.name
    assert_equal "Goal that can be retrieved after declaration", retrieved_goal.description
    assert_equal :test_strategy, retrieved_goal.strategy
  end

  private

  # Mock evaluator for testing
  class MockEvaluator
    def object_mode_enabled?
      false
    end
  end
end