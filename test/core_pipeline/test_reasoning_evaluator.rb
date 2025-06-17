# frozen_string_literal: true

require_relative '../helpers/test_helper'

class TestReasoningEvaluator < Minitest::Test
  def setup
    @mock_evaluator = MockEvaluator.new
    @reasoning_evaluator = EvaluatorModules::ReasoningEvaluator.new(@mock_evaluator)
  end

  # Test initialization and basic properties
  def test_reasoning_evaluator_initialization
    assert_not_nil @reasoning_evaluator
    assert_not @reasoning_evaluator.reasoning_mode_enabled
    assert_not_nil @reasoning_evaluator.constraint_system
    assert_not_nil @reasoning_evaluator.unification_engine
    assert_kind_of TypeConstraintSystem, @reasoning_evaluator.constraint_system
    assert_kind_of UnificationEngine, @reasoning_evaluator.unification_engine
  end

  def test_reasoning_evaluator_performance_stats_initialization
    # Should initialize performance stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_not_nil stats
    assert_equal 0, stats[:assignments_validated]
    assert_equal 0, stats[:constraints_checked]
    assert_equal 0, stats[:violations_detected]
    assert_equal 0, stats[:reasoning_operations]
    assert_kind_of Time, stats[:start_time]
  end

  # Test reasoning mode management
  def test_enable_reasoning_mode
    assert_not @reasoning_evaluator.reasoning_mode_enabled
    
    @reasoning_evaluator.enable_reasoning_mode
    
    assert @reasoning_evaluator.reasoning_mode_enabled
    
    # Should update performance stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_not_nil stats[:reasoning_mode_enabled_at]
    assert_kind_of Time, stats[:reasoning_mode_enabled_at]
  end

  def test_disable_reasoning_mode
    @reasoning_evaluator.enable_reasoning_mode
    assert @reasoning_evaluator.reasoning_mode_enabled
    
    @reasoning_evaluator.disable_reasoning_mode
    
    assert_not @reasoning_evaluator.reasoning_mode_enabled
    
    # Should update performance stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_not_nil stats[:reasoning_mode_disabled_at]
    assert_kind_of Time, stats[:reasoning_mode_disabled_at]
  end

  def test_reasoning_mode_toggle_multiple_times
    # Test multiple enable/disable cycles
    5.times do
      @reasoning_evaluator.enable_reasoning_mode
      assert @reasoning_evaluator.reasoning_mode_enabled
      
      @reasoning_evaluator.disable_reasoning_mode
      assert_not @reasoning_evaluator.reasoning_mode_enabled
    end
  end

  # Test type constraint node visiting
  def test_visit_type_constraint_node_with_reasoning_mode_enabled
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create a mock type constraint node
    node = Object.new
    def node.variable; :test_var; end
    def node.constraint_type; "number"; end
    def node.conditions; []; end
    
    result = @reasoning_evaluator.visit_type_constraint_node(node)
    
    assert_not_nil result
    assert_kind_of TypeConstraint, result
    
    # Should update performance stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_equal 1, stats[:constraints_checked]
  end

  def test_visit_type_constraint_node_without_reasoning_mode
    # Reasoning mode is disabled by default
    assert_not @reasoning_evaluator.reasoning_mode_enabled
    
    node = Object.new
    def node.variable; :test_var; end
    def node.constraint_type; "number"; end
    def node.conditions; []; end
    
    # Should raise ReasoningModeError
    error = assert_raises(ReasoningModeError) do
      @reasoning_evaluator.visit_type_constraint_node(node)
    end
    
    assert_includes error.message, "Type constraints require reasoning mode"
    assert_includes error.message, "reasoning mode on"
  end

  def test_visit_type_constraint_node_with_conditions
    @reasoning_evaluator.enable_reasoning_mode
    
    node = Object.new
    def node.variable; :test_var; end
    def node.constraint_type; "number"; end
    def node.conditions; [:positive, :integer]; end
    
    result = @reasoning_evaluator.visit_type_constraint_node(node)
    
    assert_not_nil result
    assert_kind_of TypeConstraint, result
    assert_equal :test_var, result.variable
    assert_equal :type, result.constraint_type
    assert_equal :number, result.constraint_data
  end

  # Test assignment validation
  def test_validate_assignment_without_reasoning_mode
    # Should return true when reasoning mode is disabled
    result = @reasoning_evaluator.validate_assignment("test_var", 42)
    assert_equal true, result
    
    # Should not update performance stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_equal 0, stats[:assignments_validated]
  end

  def test_validate_assignment_with_reasoning_mode_no_constraints
    @reasoning_evaluator.enable_reasoning_mode
    
    # Should return true when no constraints exist for the variable
    result = @reasoning_evaluator.validate_assignment("unconstrained_var", 42)
    assert_equal true, result
    
    # Should update performance stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_equal 1, stats[:assignments_validated]
  end

  def test_validate_assignment_with_satisfied_constraints
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create a constraint that should be satisfied
    @reasoning_evaluator.create_constraint("number_var", :type, :number)
    
    # Should return true for valid assignment
    result = @reasoning_evaluator.validate_assignment("number_var", 42)
    assert_equal true, result
    
    result = @reasoning_evaluator.validate_assignment("number_var", 3.14)
    assert_equal true, result
  end

  def test_validate_assignment_with_violated_constraints
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create a constraint that will be violated
    @reasoning_evaluator.create_constraint("number_var", :type, :number)
    
    # Should raise error for invalid assignment
    error = assert_raises(StandardError) do
      @reasoning_evaluator.validate_assignment("number_var", "not_a_number")
    end
    
    assert_includes error.message, "Assignment violates constraint"
    assert_includes error.message, "number_var"
    
    # Should update violation stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_operator stats[:violations_detected], :>, 0
  end

  def test_validate_assignment_with_multiple_constraints
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create multiple constraints
    @reasoning_evaluator.create_constraint("constrained_var", :type, :number)
    @reasoning_evaluator.create_constraint("constrained_var", :range, 1..100)
    
    # Should satisfy all constraints
    result = @reasoning_evaluator.validate_assignment("constrained_var", 50)
    assert_equal true, result
    
    # Should violate type constraint
    assert_raises(StandardError) do
      @reasoning_evaluator.validate_assignment("constrained_var", "string")
    end
    
    # Should violate range constraint
    assert_raises(StandardError) do
      @reasoning_evaluator.validate_assignment("constrained_var", 150)
    end
  end

  def test_validate_assignment_updates_constraint_system
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create constraint
    @reasoning_evaluator.create_constraint("tracked_var", :type, :number)
    
    # Validate assignment
    @reasoning_evaluator.validate_assignment("tracked_var", 42)
    
    # Should update constraint system with the value
    constraint_system = @reasoning_evaluator.constraint_system
    variables = constraint_system.instance_variable_get(:@variable_values)
    assert_not_nil variables
    assert_equal 42, variables["tracked_var"]
  end

  # Test constraint creation
  def test_create_constraint_with_reasoning_mode_enabled
    @reasoning_evaluator.enable_reasoning_mode
    
    result = @reasoning_evaluator.create_constraint("test_var", :type, :string)
    
    assert_not_nil result
    assert_kind_of TypeConstraint, result
    assert_equal :test_var, result.variable
    
    # Should update performance stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_equal 1, stats[:reasoning_operations]
  end

  def test_create_constraint_without_reasoning_mode
    # Should raise ReasoningModeError when reasoning mode is disabled
    error = assert_raises(ReasoningModeError) do
      @reasoning_evaluator.create_constraint("test_var", :type, :string)
    end
    
    assert_includes error.message, "Constraint creation requires reasoning mode"
    assert_includes error.message, "reasoning mode on"
  end

  def test_create_constraint_with_options
    @reasoning_evaluator.enable_reasoning_mode
    
    options = { conditions: [:non_empty], metadata: { strict: true } }
    result = @reasoning_evaluator.create_constraint("test_var", :type, :string, **options)
    
    assert_not_nil result
    assert_kind_of TypeConstraint, result
  end

  def test_create_multiple_constraints
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create multiple constraints
    constraint1 = @reasoning_evaluator.create_constraint("var1", :type, :number)
    constraint2 = @reasoning_evaluator.create_constraint("var2", :type, :string)
    constraint3 = @reasoning_evaluator.create_constraint("var1", :range, 1..100)
    
    assert_not_nil constraint1
    assert_not_nil constraint2
    assert_not_nil constraint3
    
    # Should update performance stats
    stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    assert_equal 3, stats[:reasoning_operations]
  end

  # Test performance characteristics
  def test_performance_stats_tracking
    initial_stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create constraints
    5.times do |i|
      @reasoning_evaluator.create_constraint("var#{i}", :type, :number)
    end
    
    # Validate assignments
    10.times do |i|
      @reasoning_evaluator.validate_assignment("var#{i % 5}", i)
    end
    
    # Visit type constraint nodes
    3.times do |i|
      node = Object.new
      def node.variable; :test_var; end
      def node.constraint_type; "number"; end
      def node.conditions; []; end
      
      @reasoning_evaluator.visit_type_constraint_node(node)
    end
    
    final_stats = @reasoning_evaluator.instance_variable_get(:@performance_stats)
    
    assert_equal 5, final_stats[:reasoning_operations]
    assert_equal 10, final_stats[:assignments_validated]
    assert_equal 3, final_stats[:constraints_checked]
  end

  def test_performance_with_many_constraints
    @reasoning_evaluator.enable_reasoning_mode
    
    start_time = Time.now
    
    # Create many constraints
    100.times do |i|
      @reasoning_evaluator.create_constraint("var#{i}", :type, :number)
    end
    
    # Validate many assignments
    100.times do |i|
      @reasoning_evaluator.validate_assignment("var#{i}", i)
    end
    
    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 2.0, "Reasoning evaluator should handle many constraints efficiently"
  end

  # Test error handling and edge cases
  def test_constraint_violation_error_details
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create constraint
    @reasoning_evaluator.create_constraint("detailed_var", :type, :number)
    
    # Should provide detailed error message
    error = assert_raises(StandardError) do
      @reasoning_evaluator.validate_assignment("detailed_var", "string_value")
    end
    
    assert_includes error.message, "detailed_var"
    assert_includes error.message, "string_value"
    assert_includes error.message, "type constraint"
  end

  def test_constraint_system_integration
    @reasoning_evaluator.enable_reasoning_mode
    
    # Test integration with underlying constraint system
    constraint_system = @reasoning_evaluator.constraint_system
    
    # Create constraint through reasoning evaluator
    @reasoning_evaluator.create_constraint("integration_var", :type, :string)
    
    # Should be available in constraint system
    constraints = constraint_system.instance_variable_get(:@constraints)
    assert_not_nil constraints["integration_var"]
    assert_operator constraints["integration_var"].length, :>, 0
  end

  def test_unification_engine_integration
    @reasoning_evaluator.enable_reasoning_mode
    
    # Test that unification engine is properly initialized
    unification_engine = @reasoning_evaluator.unification_engine
    
    assert_not_nil unification_engine
    assert_kind_of UnificationEngine, unification_engine
    assert_respond_to unification_engine, :unify
  end

  def test_reasoning_evaluator_with_complex_constraints
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create complex constraint scenario
    @reasoning_evaluator.create_constraint("complex_var", :type, :number)
    @reasoning_evaluator.create_constraint("complex_var", :range, 1..100)
    
    # Test edge cases
    assert @reasoning_evaluator.validate_assignment("complex_var", 1)   # Lower bound
    assert @reasoning_evaluator.validate_assignment("complex_var", 100) # Upper bound
    assert @reasoning_evaluator.validate_assignment("complex_var", 50)  # Middle value
    
    # Test violations
    assert_raises(StandardError) { @reasoning_evaluator.validate_assignment("complex_var", 0) }
    assert_raises(StandardError) { @reasoning_evaluator.validate_assignment("complex_var", 101) }
    assert_raises(StandardError) { @reasoning_evaluator.validate_assignment("complex_var", "string") }
  end

  def test_reasoning_evaluator_memory_efficiency
    @reasoning_evaluator.enable_reasoning_mode
    
    # Test memory efficiency with many operations
    original_constraint_count = @reasoning_evaluator.constraint_system.constraint_count
    
    # Perform many operations
    50.times do |i|
      @reasoning_evaluator.create_constraint("mem_var#{i}", :type, :number)
      @reasoning_evaluator.validate_assignment("mem_var#{i}", i)
    end
    
    # Should have created constraints efficiently
    new_constraint_count = @reasoning_evaluator.constraint_system.constraint_count
    assert_equal original_constraint_count + 50, new_constraint_count
  end

  def test_reasoning_evaluator_state_consistency
    # Test that reasoning evaluator maintains consistent state
    initial_reasoning_mode = @reasoning_evaluator.reasoning_mode_enabled
    
    # Perform various operations
    @reasoning_evaluator.enable_reasoning_mode
    @reasoning_evaluator.create_constraint("state_var", :type, :number)
    @reasoning_evaluator.validate_assignment("state_var", 42)
    @reasoning_evaluator.disable_reasoning_mode
    
    # State should be consistent
    assert_not @reasoning_evaluator.reasoning_mode_enabled
    assert_not_nil @reasoning_evaluator.constraint_system
    assert_not_nil @reasoning_evaluator.unification_engine
  end

  def test_reasoning_evaluator_concurrent_operations
    @reasoning_evaluator.enable_reasoning_mode
    
    # Simulate concurrent constraint creation and validation
    threads = []
    results = []
    
    10.times do |i|
      threads << Thread.new do
        @reasoning_evaluator.create_constraint("thread_var#{i}", :type, :number)
        result = @reasoning_evaluator.validate_assignment("thread_var#{i}", i)
        results << result
      end
    end
    
    threads.each(&:join)
    
    # All operations should succeed
    assert_equal 10, results.length
    results.each { |result| assert_equal true, result }
  end

  def test_reasoning_evaluator_error_recovery
    @reasoning_evaluator.enable_reasoning_mode
    
    # Create constraint
    @reasoning_evaluator.create_constraint("recovery_var", :type, :number)
    
    # Cause a violation
    assert_raises(StandardError) do
      @reasoning_evaluator.validate_assignment("recovery_var", "invalid")
    end
    
    # Should still work for valid assignments
    result = @reasoning_evaluator.validate_assignment("recovery_var", 42)
    assert_equal true, result
    
    # Should still be able to create new constraints
    new_constraint = @reasoning_evaluator.create_constraint("new_var", :type, :string)
    assert_not_nil new_constraint
  end

  def test_reasoning_evaluator_with_nil_values
    @reasoning_evaluator.enable_reasoning_mode
    
    # Test handling of nil values
    @reasoning_evaluator.create_constraint("nil_test_var", :type, :number)
    
    # Should handle nil assignment appropriately
    assert_raises(StandardError) do
      @reasoning_evaluator.validate_assignment("nil_test_var", nil)
    end
  end
end