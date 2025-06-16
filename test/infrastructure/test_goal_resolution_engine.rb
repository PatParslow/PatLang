# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/goal_system'
require_relative '../../src/reasoning/reasoning_coordinator'

# Comprehensive tests for the goal resolution engine
class TestGoalResolutionEngine < Minitest::Test
  def setup
    @evaluator = MockEvaluator.new
    @goal_system = GoalSystem.new(@evaluator)
    @reasoning_coordinator = ReasoningCoordinator.new(@evaluator)
    @goal_system.set_reasoning_coordinator(@reasoning_coordinator)
    @event_log = []
    
    # Subscribe to goal events
    @goal_system.on_event(:goal_declared) { |e| @event_log << e }
    @goal_system.on_event(:goal_pursued) { |e| @event_log << e }
    @goal_system.on_event(:goal_achieved) { |e| @event_log << e }
    @goal_system.on_event(:goal_failed) { |e| @event_log << e }
    @goal_system.on_event(:strategy_executed) { |e| @event_log << e }
    @goal_system.on_event(:concurrent_goals_completed) { |e| @event_log << e }
    @goal_system.on_event(:monitoring_started) { |e| @event_log << e }
  end

  # === Basic Goal Declaration Tests ===

  def test_declare_simple_goal_succeeds
    goal_definition = <<~GOAL
      goal find_number {
        description: "Find an even number between 20 and 30"
        postcondition: result.even? and result > 20 and result < 30
      }
    GOAL
    
    goal = @goal_system.declare_goal(:find_number, goal_definition)
    
    assert_instance_of Goal, goal
    assert_equal :find_number, goal.name
    assert_equal "Find an even number between 20 and 30", goal.description
    assert goal.has_postcondition?
    refute goal.has_precondition?
    assert_events_fired [:goal_declared]
  end

  def test_declare_goal_with_preconditions
    goal_definition = <<~GOAL
      goal validate_input {
        description: "Validate user input"
        precondition: a != 0
        postcondition: result > 10 and result < 100 and result.even?
      }
    GOAL
    
    goal = @goal_system.declare_goal(:validate_input, goal_definition)
    
    assert goal.has_precondition?
    assert goal.has_postcondition?
    assert_equal ["a != 0"], goal.preconditions
    assert_equal ["result > 10 and result < 100 and result.even?"], goal.postconditions
  end

  def test_declare_goal_with_strategies
    goal_definition = <<~GOAL
      goal optimize_search {
        description: "Optimize search performance"
        strategy: binary_search
        strategies: [linear_search, binary_search, hash_lookup]
        preference: fastest
      }
    GOAL
    
    goal = @goal_system.declare_goal(:optimize_search, goal_definition)
    
    assert_equal :binary_search, goal.strategy
    assert_equal [:linear_search, :binary_search, :hash_lookup], goal.strategies
    assert_equal :fastest, goal.preference
    assert goal.has_multiple_strategies?
  end

  def test_declare_goal_with_subgoals
    goal_definition = <<~GOAL
      goal complex_task {
        description: "Complete complex multi-step task"
        subgoals: [prepare_data, process_data, validate_results]
        strategy: sequential
      }
    GOAL
    
    goal = @goal_system.declare_goal(:complex_task, goal_definition)
    
    assert goal.has_subgoals?
    assert_equal [:prepare_data, :process_data, :validate_results], goal.subgoals
  end

  def test_declare_goal_with_context
    goal_definition = <<~GOAL
      goal find_in_range {
        description: "Find value in specified range"
        context: {min: 10, max: 50, type: number}
        postcondition: result >= min and result <= max
      }
    GOAL
    
    goal = @goal_system.declare_goal(:find_in_range, goal_definition)
    
    assert_instance_of Hash, goal.context
    refute_empty goal.context
  end

  # === Goal Pursuit and Resolution Tests ===

  def test_pursue_simple_goal_succeeds
    goal_definition = <<~GOAL
      goal find_even_number {
        description: "Find an even number"
        postcondition: result.even? and result > 20 and result < 30
      }
    GOAL
    
    @goal_system.declare_goal(:find_even_number, goal_definition)
    result = @goal_system.pursue_goal(:find_even_number)
    
    assert_instance_of Integer, result
    assert result.even?
    assert_operator result, :>, 20
    assert_operator result, :<, 30
    assert_events_fired [:goal_pursued, :goal_achieved]
  end

  def test_pursue_goal_with_context
    goal_definition = <<~GOAL
      goal find_factors {
        description: "Find factors of a number"
        postcondition: result.is_a?(Array)
      }
    GOAL
    
    @goal_system.declare_goal(:find_factors, goal_definition)
    result = @goal_system.pursue_goal(:find_factors, number: 12)
    
    assert_instance_of Array, result
    expected_factors = [1, 2, 3, 4, 6, 12]
    assert_equal expected_factors, result
  end

  def test_pursue_goal_validates_preconditions
    goal_definition = <<~GOAL
      goal conditional_goal {
        description: "Goal with preconditions"
        precondition: a != 0
        postcondition: result > 10
      }
    GOAL
    
    @goal_system.declare_goal(:conditional_goal, goal_definition)
    
    # Should succeed with valid precondition
    assert_nothing_raised do
      @goal_system.pursue_goal(:conditional_goal, a: 5)
    end
    
    # Should fail with invalid precondition
    error = assert_raises(RuntimeError) do
      @goal_system.pursue_goal(:conditional_goal, a: 0)
    end
    
    assert_includes error.message, "Preconditions not satisfied"
    assert_events_include :goal_failed
  end

  def test_pursue_goal_validates_postconditions
    goal_definition = <<~GOAL
      goal strict_goal {
        description: "Goal with strict postconditions"
        postcondition: result > 10 and result < 100 and result.even?
      }
    GOAL
    
    @goal_system.declare_goal(:strict_goal, goal_definition)
    
    # Mock a goal that might fail postconditions
    class << @goal_system
      def execute_goal_strategy(goal, strategy, context)
        return 5 if goal.name == :strict_goal  # This violates postcondition
        super
      end
    end
    
    error = assert_raises(RuntimeError) do
      @goal_system.pursue_goal(:strict_goal)
    end
    
    assert_includes error.message, "Postconditions not satisfied"
    assert_events_include :goal_failed
  end

  def test_pursue_undefined_goal_raises_error
    error = assert_raises(ArgumentError) do
      @goal_system.pursue_goal(:undefined_goal)
    end
    
    assert_includes error.message, "Goal undefined_goal not found"
  end

  # === Strategy Execution Tests ===

  def test_goal_strategies_execute_correctly
    # Test various built-in goal strategies
    test_cases = [
      { name: :find_even_number, expected_class: Integer, validation: ->(r) { r.even? } },
      { name: :find_perfect_square, expected_class: Integer, validation: ->(r) { Math.sqrt(r) == Math.sqrt(r).to_i } },
      { name: :find_prime_number, context: { min: 10, max: 20 }, expected_class: Integer, validation: ->(r) { prime?(r) } }
    ]
    
    test_cases.each do |test_case|
      goal_definition = %Q{
        goal #{test_case[:name]} {
          description: "Test goal for #{test_case[:name]}"
        }
      }
      
      @goal_system.declare_goal(test_case[:name], goal_definition)
      result = @goal_system.pursue_goal(test_case[:name], **(test_case[:context] || {}))
      
      assert_instance_of test_case[:expected_class], result, "#{test_case[:name]} should return #{test_case[:expected_class]}"
      if test_case[:validation]
        assert test_case[:validation].call(result), "#{test_case[:name]} result #{result} failed validation"
      end
    end
  end

  def test_strategy_execution_fires_events
    goal_definition = <<~GOAL
      goal test_strategy {
        description: "Test strategy execution"
        strategy: custom_strategy
      }
    GOAL
    
    @goal_system.declare_goal(:test_strategy, goal_definition)
    @goal_system.pursue_goal(:test_strategy)
    
    strategy_events = @event_log.select { |e| e[:event_type] == :strategy_executed }
    assert strategy_events.any?, "Strategy execution should fire events"
    
    strategy_event = strategy_events.first
    assert_equal :test_strategy, strategy_event[:goal]
    assert_equal :custom_strategy, strategy_event[:strategy]
  end

  # === Concurrent Goal Execution Tests ===

  def test_pursue_goals_concurrently_succeeds
    # Declare multiple simple goals
    [:goal_a, :goal_b, :goal_c].each do |name|
      goal_definition = %Q{
        goal #{name} {
          description: "Concurrent goal #{name}"
        }
      }
      @goal_system.declare_goal(name, goal_definition)
    end
    
    start_time = Time.now
    results = @goal_system.pursue_goals_concurrently([:goal_a, :goal_b, :goal_c])
    duration = Time.now - start_time
    
    assert_instance_of Array, results
    assert_equal 3, results.length
    assert_operator duration, :<, 1.0, "Concurrent execution should be reasonably fast"
    assert_events_include :concurrent_goals_completed
  end

  def test_concurrent_goals_share_context
    goal_definition = <<~GOAL
      goal shared_context_goal {
        description: "Goal that uses shared context"
      }
    GOAL
    
    @goal_system.declare_goal(:shared_context_goal, goal_definition)
    
    shared_context = { shared_value: 42 }
    results = @goal_system.pursue_goals_concurrently(
      [:shared_context_goal, :shared_context_goal], 
      **shared_context
    )
    
    assert_equal 2, results.length
    # Both goals should have access to the shared context
    assert results.all? { |r| r.is_a?(Integer) }
  end

  # === Execution Planning Tests ===

  def test_create_execution_plan_for_simple_goal
    goal_definition = <<~GOAL
      goal simple_plan {
        description: "Simple goal for planning"
      }
    GOAL
    
    @goal_system.declare_goal(:simple_plan, goal_definition)
    plan = @goal_system.create_execution_plan(:simple_plan)
    
    assert_instance_of ExecutionPlan, plan
    assert_equal :simple_plan, plan.goal_name
    assert_instance_of Array, plan.execution_order
    assert_instance_of Hash, plan.dependencies
  end

  def test_create_execution_plan_with_subgoals
    goal_definition = <<~GOAL
      goal complex_plan {
        description: "Complex goal with subgoals"
        subgoals: [step_one, step_two, step_three]
      }
    GOAL
    
    @goal_system.declare_goal(:complex_plan, goal_definition)
    plan = @goal_system.create_execution_plan(:complex_plan)
    
    expected_order = [:step_one, :step_two, :step_three, :complex_plan]
    assert_equal expected_order, plan.execution_order
  end

  def test_execution_plan_step_validation
    plan = ExecutionPlan.new(:test_goal, 
      execution_order: [:step_a, :step_b, :step_c],
      dependencies: { step_b: [:step_a], step_c: [:step_a, :step_b] }
    )
    
    assert plan.can_execute?(:step_a)
    refute plan.can_execute?(:step_b)  # step_a hasn't been completed yet
    refute plan.can_execute?(:step_c)  # dependencies not met
  end

  # === Goal Monitoring Tests ===

  def test_start_monitoring_creates_monitor
    goal_definition = <<~GOAL
      goal monitored_goal {
        description: "Goal with monitoring"
      }
    GOAL
    
    @goal_system.declare_goal(:monitored_goal, goal_definition)
    monitor = @goal_system.start_monitoring(:monitored_goal)
    
    assert_instance_of GoalMonitor, monitor
    assert_equal :monitored_goal, monitor.goal_name
    assert_instance_of Integer, monitor.monitoring_interval
    assert_instance_of Array, monitor.tracked_metrics
    assert_events_include :monitoring_started
  end

  def test_goal_monitor_tracks_metrics
    monitor = GoalMonitor.new(:test_goal, 
      monitoring_interval: 5,
      tracked_metrics: [:performance, :accuracy]
    )
    
    assert monitor.tracks_metric?(:performance)
    assert monitor.tracks_metric?(:accuracy)
    refute monitor.tracks_metric?(:unknown_metric)
    
    monitor.update_metric(:performance, 0.95)
    assert_equal 0.95, monitor.get_metric(:performance)
  end

  # === Resource Scheduling Tests ===

  def test_resource_scheduler_availability
    scheduler = @goal_system.resource_scheduler
    
    assert_instance_of ResourceScheduler, scheduler
    assert scheduler.can_schedule_goal?(:test_goal)
    
    next_slot = scheduler.next_available_slot(:test_goal)
    assert_instance_of Time, next_slot
    assert_operator next_slot, :>, Time.now
  end

  def test_resource_scheduler_goal_scheduling
    scheduler = @goal_system.resource_scheduler
    resource_requirements = { cpu_cores: 2, memory: "4GB" }
    
    result = scheduler.schedule_goal(:test_goal, resource_requirements)
    assert result, "Goal scheduling should succeed"
  end

  # === Goal System Integration Tests ===

  def test_goal_system_integrates_with_reasoning_coordinator
    assert_instance_of ReasoningCoordinator, @goal_system.instance_variable_get(:@reasoning_coordinator)
  end

  def test_get_goal_retrieves_declared_goals
    goal_definition = <<~GOAL
      goal retrievable_goal {
        description: "Goal for retrieval testing"
      }
    GOAL
    
    declared_goal = @goal_system.declare_goal(:retrievable_goal, goal_definition)
    retrieved_goal = @goal_system.get_goal(:retrievable_goal)
    
    assert_equal declared_goal, retrieved_goal
    assert_equal :retrievable_goal, retrieved_goal.name
  end

  def test_all_goals_returns_collection
    # Declare multiple goals
    3.times do |i|
      goal_name = "goal_#{i}".to_sym
      goal_definition = %Q{
        goal #{goal_name} {
          description: "Test goal #{i}"
        }
      }
      @goal_system.declare_goal(goal_name, goal_definition)
    end
    
    all_goals = @goal_system.all_goals
    assert_instance_of Array, all_goals
    assert_equal 3, all_goals.length
    assert all_goals.all? { |g| g.is_a?(Goal) }
  end

  # === Performance Tests ===

  def test_goal_declaration_performance
    start_time = Time.now
    
    50.times do |i|
      goal_definition = %Q{
        goal performance_goal_#{i} {
          description: "Performance test goal #{i}"
        }
      }
      @goal_system.declare_goal("performance_goal_#{i}".to_sym, goal_definition)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.5, "50 goal declarations should complete in <500ms"
  end

  def test_goal_pursuit_performance
    # Declare goals first
    10.times do |i|
      goal_definition = %Q{
        goal speed_goal_#{i} {
          description: "Speed test goal #{i}"
        }
      }
      @goal_system.declare_goal("speed_goal_#{i}".to_sym, goal_definition)
    end
    
    start_time = Time.now
    
    10.times do |i|
      @goal_system.pursue_goal("speed_goal_#{i}".to_sym)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.1, "10 goal pursuits should complete in <100ms"
  end

  def test_concurrent_goal_execution_performance
    # Declare goals for concurrent execution
    goal_names = []
    5.times do |i|
      goal_name = "concurrent_perf_#{i}".to_sym
      goal_names << goal_name
      goal_definition = %Q{
        goal #{goal_name} {
          description: "Concurrent performance goal #{i}"
        }
      }
      @goal_system.declare_goal(goal_name, goal_definition)
    end
    
    start_time = Time.now
    results = @goal_system.pursue_goals_concurrently(goal_names)
    duration = Time.now - start_time
    
    assert_equal 5, results.length
    assert_operator duration, :<, 0.2, "5 concurrent goals should complete in <200ms"
  end

  # === Error Handling and Edge Cases ===

  def test_malformed_goal_definition_handling
    malformed_definition = "invalid goal syntax"
    
    goal = @goal_system.declare_goal(:malformed_goal, malformed_definition)
    
    # Should still create a goal object, but with minimal content
    assert_instance_of Goal, goal
    assert_equal :malformed_goal, goal.name
  end

  def test_goal_with_empty_definition
    empty_definition = ""
    
    goal = @goal_system.declare_goal(:empty_goal, empty_definition)
    
    assert_instance_of Goal, goal
    assert_equal :empty_goal, goal.name
    refute goal.has_precondition?
    refute goal.has_postcondition?
  end

  def test_goal_pursuit_with_nil_context
    goal_definition = <<~GOAL
      goal nil_context_goal {
        description: "Goal that handles nil context"
      }
    GOAL
    
    @goal_system.declare_goal(:nil_context_goal, goal_definition)
    
    assert_nothing_raised do
      result = @goal_system.pursue_goal(:nil_context_goal, nil)
      assert_instance_of Integer, result
    end
  end

  private

  def assert_events_fired(expected_event_types)
    actual_event_types = @event_log.map { |e| e[:event_type] }
    expected_event_types.each do |expected_type|
      assert_includes actual_event_types, expected_type,
                     "Expected event #{expected_type} to be fired"
    end
  end

  def assert_events_include(event_type)
    event_types = @event_log.map { |e| e[:event_type] }
    assert_includes event_types, event_type,
                   "Expected events to include #{event_type}"
  end

  def prime?(n)
    return false if n < 2
    return true if n == 2
    return false if n.even?
    
    (3..Math.sqrt(n)).step(2) do |i|
      return false if n % i == 0
    end
    true
  end

  # Mock evaluator for testing
  class MockEvaluator
    def object_mode_enabled?
      false
    end
  end
end