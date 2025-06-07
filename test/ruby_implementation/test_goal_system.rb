# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/evaluator'
require_relative '../../src/reasoning/goal_system'
require_relative '../../src/reasoning/reasoning_coordinator'

# Test comprehensive goal declaration, pursuit, and achievement system
# This demonstrates high business value through problem-solving capabilities
class TestGoalSystem < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    @evaluator.enable_object_mode
    @goal_system = GoalSystem.new(@evaluator)
    @reasoning_coordinator = ReasoningCoordinator.new(@evaluator)
    @goal_system.set_reasoning_coordinator(@reasoning_coordinator)
    
    @event_log = []
    @goal_system.on_event(:goal_declared) { |e| @event_log << e }
    @goal_system.on_event(:goal_pursued) { |e| @event_log << e }
    @goal_system.on_event(:goal_achieved) { |e| @event_log << e }
    @goal_system.on_event(:goal_failed) { |e| @event_log << e }
    @goal_system.on_event(:strategy_executed) { |e| @event_log << e }
  end

  # === Basic Goal Declaration and Structure ===

  def test_simple_goal_declaration
    goal_definition = <<~PATLANG
      goal find_optimal_value {
        description: "Find a value that satisfies multiple criteria",
        postcondition: result > 10 and result < 100 and result.even?
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:find_optimal_value, goal_definition)
    
    assert_instance_of Goal, goal
    assert_equal :find_optimal_value, goal.name
    assert goal.has_postcondition?, "Goal should have postcondition"
    assert_includes goal.description, "Find a value"
    assert_events_include :goal_declared
  end

  def test_goal_with_parameters_and_preconditions
    goal_definition = <<~PATLANG
      goal solve_quadratic(a, b, c) {
        description: "Solve quadratic equation ax² + bx + c = 0",
        precondition: a != 0,
        postcondition: a * result^2 + b * result + c == 0,
        strategy: quadratic_formula
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:solve_quadratic, goal_definition)
    
    assert_equal [:a, :b, :c], goal.parameters
    assert goal.has_precondition?, "Goal should have precondition"
    assert goal.has_postcondition?, "Goal should have postcondition"
    assert_equal :quadratic_formula, goal.strategy
  end

  def test_goal_with_multiple_strategies
    goal_definition = <<~PATLANG
      goal find_prime_number(min, max) {
        postcondition: result.prime? and result >= min and result <= max,
        strategies: [
          trial_division,
          sieve_of_eratosthenes,
          miller_rabin_test
        ],
        preference: performance_optimized
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:find_prime_number, goal_definition)
    
    assert_equal 3, goal.strategies.length
    assert_includes goal.strategies, :trial_division
    assert_includes goal.strategies, :sieve_of_eratosthenes
    assert_includes goal.strategies, :miller_rabin_test
    assert_equal :performance_optimized, goal.preference
  end

  # === Goal Pursuit and Resolution ===

  def test_basic_goal_pursuit
    goal_definition = <<~PATLANG
      goal find_even_number {
        postcondition: result.even? and result > 20 and result < 30
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:find_even_number, goal_definition)
    result = @goal_system.pursue_goal(:find_even_number)
    
    assert result.is_a?(Numeric), "Should return a number"
    assert result.even?, "Result should be even"
    assert_operator result, :>, 20, "Result should be greater than 20"
    assert_operator result, :<, 30, "Result should be less than 30"
    assert_events_include :goal_pursued
    assert_events_include :goal_achieved
  end

  def test_goal_pursuit_with_parameters
    goal_definition = <<~PATLANG
      goal find_factors(number) {
        precondition: number > 1,
        postcondition: result.all? { |f| number % f == 0 } and result.product == number
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:find_factors, goal_definition)
    result = @goal_system.pursue_goal(:find_factors, number: 12)
    
    assert_instance_of Array, result
    assert result.all? { |f| 12 % f == 0 }, "All results should be factors of 12"
    assert_equal 12, result.reduce(:*), "Product of factors should equal original number"
  end

  def test_goal_pursuit_with_context_binding
    goal_definition = <<~PATLANG
      goal optimize_portfolio(stocks, target_return) {
        precondition: stocks.length > 0 and target_return > 0,
        postcondition: 
          result.expected_return >= target_return and
          result.risk_level <= acceptable_risk and
          result.diversification_score >= 0.7,
        context: {
          market_data: current_market_state,
          risk_tolerance: user_preferences.risk_level,
          time_horizon: investment_timeline
        }
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:optimize_portfolio, goal_definition)
    
    context = {
      stocks: ["AAPL", "GOOGL", "MSFT", "TSLA"],
      target_return: 0.12,
      market_data: { volatility: 0.15, trend: "bullish" },
      risk_tolerance: "moderate",
      time_horizon: "long_term"
    }
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      result = @goal_system.pursue_goal(:optimize_portfolio, context)
    end
  end

  # === Strategy Selection and Execution ===

  def test_automatic_strategy_selection
    goal_definition = <<~PATLANG
      goal sort_data(array, criteria) {
        postcondition: result.sorted_by?(criteria) and result.length == array.length,
        strategies: [
          { name: quicksort, performance: "O(n log n)", best_for: "general_purpose" },
          { name: mergesort, performance: "O(n log n)", best_for: "stable_sort" },
          { name: heapsort, performance: "O(n log n)", best_for: "memory_constrained" },
          { name: radixsort, performance: "O(nk)", best_for: "integer_keys" }
        ],
        strategy_selector: automatic
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:sort_data, goal_definition)
    
    # Test with different data types to trigger different strategy selection
    integer_data = [64, 34, 25, 12, 22, 11, 90]
    result = @goal_system.pursue_goal(:sort_data, array: integer_data, criteria: :ascending)
    
    assert_equal [11, 12, 22, 25, 34, 64, 90], result
    
    # Verify strategy selection event was logged
    strategy_events = @event_log.select { |e| e[:event_type] == :strategy_executed }
    assert strategy_events.any?, "Should have executed a strategy"
  end

  def test_strategy_failure_and_fallback
    goal_definition = <<~PATLANG
      goal connect_to_service(endpoint) {
        postcondition: connection.active? and connection.authenticated?,
        strategies: [
          { name: primary_connection, priority: 1, timeout: 5 },
          { name: backup_connection, priority: 2, timeout: 10 },
          { name: fallback_connection, priority: 3, timeout: 15 }
        ],
        failure_handling: try_next_strategy
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:connect_to_service, goal_definition)
    
    # Simulate failing endpoint
    failing_endpoint = "https://failing-service.example.com"
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      result = @goal_system.pursue_goal(:connect_to_service, endpoint: failing_endpoint)
      
      # Should have attempted multiple strategies
      strategy_events = @event_log.select { |e| e[:event_type] == :strategy_executed }
      assert_operator strategy_events.length, :>=, 2, "Should have tried multiple strategies"
    end
  end

  # === Hierarchical Goals and Subgoals ===

  def test_hierarchical_goal_decomposition
    parent_goal_definition = <<~PATLANG
      goal plan_vacation(destination, budget, duration) {
        postcondition: 
          plan.total_cost <= budget and
          plan.duration == duration and
          plan.satisfaction_score >= 8.0,
        subgoals: [
          find_flights(destination, duration),
          book_accommodation(destination, duration, budget * 0.4),
          plan_activities(destination, duration, budget * 0.3),
          arrange_transportation(destination)
        ]
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:plan_vacation, parent_goal_definition)
    
    assert goal.has_subgoals?, "Goal should have subgoals"
    assert_equal 4, goal.subgoals.length
    assert_includes goal.subgoals.map(&:name), :find_flights
    assert_includes goal.subgoals.map(&:name), :book_accommodation
  end

  def test_subgoal_dependency_resolution
    goal_definition = <<~PATLANG
      goal build_software_project {
        subgoals: [
          { name: setup_environment, dependencies: [] },
          { name: install_dependencies, dependencies: [setup_environment] },
          { name: compile_source, dependencies: [install_dependencies] },
          { name: run_tests, dependencies: [compile_source] },
          { name: package_application, dependencies: [run_tests] }
        ],
        postcondition: all_subgoals_completed and build.successful?
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:build_software_project, goal_definition)
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      execution_plan = @goal_system.create_execution_plan(:build_software_project)
      
      # Verify dependencies are resolved in correct order
      expected_order = [:setup_environment, :install_dependencies, :compile_source, :run_tests, :package_application]
      assert_equal expected_order, execution_plan.execution_order
    end
  end

  # === Goal Monitoring and Adaptation ===

  def test_goal_progress_monitoring
    goal_definition = <<~PATLANG
      goal train_machine_learning_model(dataset, target_accuracy) {
        postcondition: model.accuracy >= target_accuracy and model.validated?,
        progress_metrics: [
          training_loss,
          validation_accuracy,
          epochs_completed
        ],
        monitoring_interval: 10.seconds,
        early_stopping: validation_accuracy_plateau
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:train_machine_learning_model, goal_definition)
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      monitor = @goal_system.start_monitoring(:train_machine_learning_model)
      
      assert monitor.tracks_metric?(:training_loss)
      assert monitor.tracks_metric?(:validation_accuracy)
      assert_equal 10, monitor.monitoring_interval
    end
  end

  def test_adaptive_goal_adjustment
    goal_definition = <<~PATLANG
      goal optimize_database_query(query, max_execution_time) {
        postcondition: 
          result.execution_time <= max_execution_time and
          result.correctness_verified?,
        adaptation_rules: [
          { condition: "execution_time > threshold", action: "add_index" },
          { condition: "memory_usage > limit", action: "use_streaming" },
          { condition: "complexity > manageable", action: "decompose_query" }
        ]
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:optimize_database_query, goal_definition)
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      slow_query = "SELECT * FROM large_table WHERE complex_condition"
      result = @goal_system.pursue_goal(:optimize_database_query, 
                                       query: slow_query, 
                                       max_execution_time: 1.0)
      
      # Should have triggered adaptations
      adaptation_events = @event_log.select { |e| e[:event_type] == :goal_adapted }
      assert adaptation_events.any?, "Should have adapted goal strategy"
    end
  end

  # === Constraint Integration ===

  def test_goal_with_type_constraints
    goal_definition = <<~PATLANG
      goal process_user_data(data) {
        constraints: {
          data :: Object {
            user_id :: Number where user_id > 0,
            email :: String where matches(/email_pattern/),
            preferences :: Object {
              theme :: String where in_list(['light', 'dark']),
              language :: String where in_list(['en', 'es', 'fr'])
            }
          }
        },
        postcondition: result.validated? and result.processed?
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:process_user_data, goal_definition)
    
    valid_data = {
      user_id: 12345,
      email: "user@example.com",
      preferences: {
        theme: "dark",
        language: "en"
      }
    }
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      result = @goal_system.pursue_goal(:process_user_data, data: valid_data)
      assert result[:validated], "Data should be validated"
      assert result[:processed], "Data should be processed"
    end
  end

  # === Real-World Business Logic Goals ===

  def test_e_commerce_order_processing_goal
    goal_definition = <<~PATLANG
      goal process_order(order_data) {
        precondition: 
          order_data.valid? and
          inventory_available?(order_data.items) and
          payment_method_valid?(order_data.payment),
        postcondition:
          order.status == 'confirmed' and
          inventory_reserved? and
          payment_authorized? and
          shipping_scheduled?,
        subgoals: [
          validate_order_items(order_data.items),
          reserve_inventory(order_data.items),
          process_payment(order_data.payment, order_data.total),
          calculate_shipping(order_data.address),
          send_confirmation_email(order_data.customer)
        ],
        rollback_on_failure: true
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:process_order, goal_definition)
    
    order_data = {
      customer: { id: 123, email: "customer@example.com" },
      items: [
        { product_id: 456, quantity: 2, price: 29.99 },
        { product_id: 789, quantity: 1, price: 49.99 }
      ],
      payment: { method: "credit_card", token: "tok_123" },
      address: { street: "123 Main St", city: "Anytown", zip: "12345" },
      total: 109.97
    }
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      result = @goal_system.pursue_goal(:process_order, order_data: order_data)
    end
  end

  def test_scientific_research_goal
    goal_definition = <<~PATLANG
      goal analyze_experimental_data(experiment_id) {
        precondition: experiment.completed? and data.quality_checked?,
        postcondition: 
          analysis.statistical_significance >= 0.95 and
          analysis.peer_reviewed? and
          results.reproducible?,
        methodology: [
          load_experimental_data(experiment_id),
          clean_and_validate_data,
          apply_statistical_tests,
          generate_visualizations,
          perform_peer_review,
          document_methodology
        ],
        quality_gates: [
          data_completeness_check,
          statistical_validity_check,
          reproducibility_verification
        ]
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:analyze_experimental_data, goal_definition)
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      result = @goal_system.pursue_goal(:analyze_experimental_data, experiment_id: "EXP_2024_001")
    end
  end

  # === Performance and Scalability ===

  def test_concurrent_goal_pursuit
    goals = []
    
    5.times do |i|
      goal_definition = <<~PATLANG
        goal parallel_computation_#{i}(input) {
          postcondition: result.computed? and result.valid?,
          execution_mode: concurrent,
          resource_requirements: { cpu: 1, memory: "100MB" }
        }
      PATLANG
      
      goals << @goal_system.declare_goal("parallel_computation_#{i}".to_sym, goal_definition)
    end
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      start_time = Time.now
      results = @goal_system.pursue_goals_concurrently(goals.map(&:name), input: "test_data")
      duration = Time.now - start_time
      
      assert_equal 5, results.length
      assert_operator duration, :<, 2.0, "Concurrent execution should be faster than sequential"
    end
  end

  def test_resource_aware_goal_scheduling
    goal_definition = <<~PATLANG
      goal resource_intensive_task(data) {
        postcondition: result.processed? and result.accurate?,
        resource_requirements: {
          cpu_cores: 4,
          memory: "8GB",
          disk_space: "10GB",
          network_bandwidth: "100Mbps"
        },
        scheduling_priority: high,
        estimated_duration: 30.minutes
      }
    PATLANG
    
    goal = @goal_system.declare_goal(:resource_intensive_task, goal_definition)
    
    # Should fail initially (RED phase)
    assert_raises(NoMethodError) do
      scheduler = @goal_system.resource_scheduler
      can_schedule = scheduler.can_schedule_goal?(:resource_intensive_task)
      
      if can_schedule
        result = @goal_system.pursue_goal(:resource_intensive_task, data: "large_dataset")
        assert result[:processed]
      else
        scheduled_time = scheduler.next_available_slot(:resource_intensive_task)
        assert scheduled_time > Time.now
      end
    end
  end

  private

  def assert_events_include(event_type)
    event_types = @event_log.map { |e| e[:event_type] }
    assert_includes event_types, event_type, "Expected #{event_type} event to be fired"
  end
end

# === Supporting Classes for RED Phase ===


# Duplicate Goal class removed - using the one from goal_system.rb