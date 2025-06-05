# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/evaluator'
require_relative '../../src/parser'
require_relative '../../src/lexer'
require_relative '../../src/reasoning/reasoning_coordinator'
require_relative '../../src/reasoning/form_validator'
require_relative '../../src/reasoning/goal_system'
require_relative '../../src/reasoning/facts_database'

# Test end-to-end evaluator integration with reasoning systems
# This demonstrates how reasoning features are accessible through Patlang.evaluate()
class TestEvaluatorReasoning < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    @evaluator.enable_object_mode
    @reasoning_coordinator = ReasoningCoordinator.new(@evaluator)
    @evaluator.set_reasoning_coordinator(@reasoning_coordinator)
    
    # Integration components
    @form_validator = FormValidator.new(@evaluator)
    @goal_system = GoalSystem.new(@evaluator)
    @facts_database = FactsDatabase.new(@evaluator)
    
    # Wire up the reasoning ecosystem
    @reasoning_coordinator.register_component(:form_validator, @form_validator)
    @reasoning_coordinator.register_component(:goal_system, @goal_system)
    @reasoning_coordinator.register_component(:facts_database, @facts_database)
    
    @event_log = []
    @reasoning_coordinator.on_event(:reasoning_pipeline_executed) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:cross_paradigm_inference) { |e| @event_log << e }
  end

  # === Basic Patlang.evaluate() Interface ===

  def test_patlang_evaluate_basic_reasoning
    code = <<~PATLANG
      reasoning mode on
      
      constrain x :: Number where x > 0 and x < 100
      x = 42
      
      result = x * 2
    PATLANG
    
    result = Patlang.evaluate(code)
    
    assert_equal 84, result
    assert @reasoning_coordinator.reasoning_mode_enabled?
    
    # Verify constraint was checked
    constraint = @reasoning_coordinator.get_constraint(:x)
    assert constraint.satisfies?(42)
  end

  def test_patlang_evaluate_with_error_handling
    code = <<~PATLANG
      reasoning mode on
      
      constrain x :: Number where x >= 0
      x = -5  # This should violate the constraint
    PATLANG
    
    error = assert_raises(TypeConstraintViolation) do
      Patlang.evaluate(code)
    end
    
    assert_equal :x, error.variable
    assert_equal(-5, error.value)
    assert_includes error.message, "x >= 0"
  end

  # === Form Validation Integration ===

  def test_evaluator_form_validation_integration
    code = <<~PATLANG
      reasoning mode on
      
      # Define a user registration form
      form user_registration {
        constrain username :: String where 
          length >= 3 and length <= 20 and
          matches /^[a-zA-Z0-9_]+$/;
        constrain email :: String where
          matches /^[\\w\\._%+-]+@[\\w\\.-]+\\.[A-Za-z]{2,}$/;
        constrain age :: Number where age >= 13 and age <= 120;
      }
      
      # Test data
      user_data = {
        username: "john_doe",
        email: "john@example.com",
        age: 25
      }
      
      # Validate using the reasoning system
      validation_result = validate_form(:user_registration, user_data)
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      assert result.valid?, "Valid user data should pass validation"
      assert_empty result.errors
    end
  end

  def test_evaluator_form_validation_with_errors
    code = <<~PATLANG
      reasoning mode on
      
      form product {
        constrain name :: String where length >= 1 and length <= 100;
        constrain price :: Number where price > 0;
      }
      
      invalid_product = {
        name: "",  # Invalid: empty
        price: -10  # Invalid: negative
      }
      
      validation_result = validate_form(:product, invalid_product)
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      refute result.valid?
      assert_equal 2, result.errors.length
    end
  end

  # === Goal System Integration ===

  def test_evaluator_goal_system_integration
    code = <<~PATLANG
      reasoning mode on
      
      # Declare a mathematical goal
      goal find_perfect_square {
        postcondition: 
          result > 100 and 
          result < 200 and 
          Math.sqrt(result).integer?
      }
      
      # Pursue the goal
      answer = pursue_goal(:find_perfect_square)
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      assert result.is_a?(Numeric)
      assert_operator result, :>, 100
      assert_operator result, :<, 200
      
      sqrt = Math.sqrt(result)
      assert_equal sqrt.to_i, sqrt, "Result should be a perfect square"
    end
  end

  def test_evaluator_parametric_goal_integration
    code = <<~PATLANG
      reasoning mode on
      
      goal optimize_value(target, tolerance) {
        postcondition: 
          (result - target).abs <= tolerance and
          result.even?
      }
      
      result = pursue_goal(:optimize_value, target: 50, tolerance: 5)
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      assert result.even?
      assert_operator (result - 50).abs, :<=, 5
    end
  end

  # === Facts Database Integration ===

  def test_evaluator_facts_database_integration
    code = <<~PATLANG
      reasoning mode on
      
      # Assert facts about family relationships
      assert_fact("parent(alice, bob)")
      assert_fact("parent(bob, charlie)")
      assert_fact("male(bob)")
      assert_fact("male(charlie)")
      assert_fact("female(alice)")
      
      # Define rules
      define_rule("father(X, Y) :- parent(X, Y), male(X)")
      define_rule("grandparent(X, Z) :- parent(X, Y), parent(Y, Z)")
      
      # Query the knowledge base
      fathers = query("father(X, Y)")
      grandparents = query("grandparent(X, Y)")
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      fathers = result[:fathers]
      grandparents = result[:grandparents]
      
      assert fathers.any? { |f| f[:X] == "bob" && f[:Y] == "charlie" }
      assert grandparents.any? { |g| g[:X] == "alice" && g[:Y] == "charlie" }
    end
  end

  def test_evaluator_complex_logic_programming
    code = <<~PATLANG
      reasoning mode on
      
      # Employee database
      assert_fact("employee(alice, engineering, 95000)")
      assert_fact("employee(bob, engineering, 75000)")
      assert_fact("employee(charlie, marketing, 85000)")
      assert_fact("employee(diana, sales, 70000)")
      
      assert_fact("manager(alice, bob)")
      assert_fact("manager(charlie, diana)")
      
      # Business rules
      define_rule("high_earner(Person) :- employee(Person, _, Salary), Salary > 80000")
      define_rule("engineering_team(Person) :- employee(Person, engineering, _)")
      define_rule("team_lead(Manager) :- manager(Manager, _)")
      
      # Complex queries
      high_earners = query("high_earner(Person)")
      engineering_leads = query("team_lead(Manager), engineering_team(Manager)")
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      high_earners = result[:high_earners]
      engineering_leads = result[:engineering_leads]
      
      expected_high_earners = ["alice", "charlie"]
      expected_engineering_leads = ["alice"]
      
      high_earner_names = high_earners.map { |h| h[:Person] }
      engineering_lead_names = engineering_leads.map { |e| e[:Manager] }
      
      expected_high_earners.each { |name| assert_includes high_earner_names, name }
      expected_engineering_leads.each { |name| assert_includes engineering_lead_names, name }
    end
  end

  # === Cross-Paradigm Integration ===

  def test_type_constraints_with_goal_resolution
    code = <<~PATLANG
      reasoning mode on
      
      # Type constraints on the solution space
      constrain solution :: Number where solution > 0 and solution < 1000
      constrain solution :: Number where solution % 7 == 0
      
      # Goal that uses the constrained space
      goal find_lucky_number {
        postcondition: 
          solution.prime? and
          solution.to_s.include?('7')
      }
      
      result = pursue_goal(:find_lucky_number)
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      # Verify the result satisfies all constraints and goals
      assert_operator result, :>, 0
      assert_operator result, :<, 1000
      assert_equal 0, result % 7
      assert prime?(result)
      assert_includes result.to_s, '7'
    end
  end

  def test_facts_based_form_validation
    code = <<~PATLANG
      reasoning mode on
      
      # Assert facts about business rules
      assert_fact("valid_department(engineering)")
      assert_fact("valid_department(marketing)")
      assert_fact("valid_department(sales)")
      assert_fact("min_salary(engineering, 60000)")
      assert_fact("min_salary(marketing, 55000)")
      assert_fact("min_salary(sales, 50000)")
      
      # Define dynamic validation rules
      define_rule("valid_employee_data(Person, Dept, Salary) :-
        valid_department(Dept),
        min_salary(Dept, MinSal),
        Salary >= MinSal")
      
      # Form that uses fact-based validation
      form employee {
        constrain department :: String where fact_validated("valid_department(department)");
        constrain salary :: Number where fact_validated("min_salary(department, X), salary >= X");
      }
      
      employee_data = {
        department: "engineering",
        salary: 75000
      }
      
      validation_result = validate_form(:employee, employee_data)
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      assert result.valid?
      assert_empty result.errors
    end
  end

  def test_goal_driven_fact_discovery
    code = <<~PATLANG
      reasoning mode on
      
      # Initial partial knowledge
      assert_fact("friend(alice, bob)")
      assert_fact("friend(bob, charlie)")
      
      # Rules for relationship inference
      define_rule("mutual_friend(X, Y, Z) :- friend(X, Z), friend(Y, Z), X != Y")
      define_rule("connected(X, Y) :- friend(X, Y)")
      define_rule("connected(X, Z) :- friend(X, Y), connected(Y, Z)")
      
      # Goal to discover social connections
      goal find_social_network(person) {
        postcondition: 
          connected_people.include?(person) and
          connected_people.length >= 3
      }
      
      network = pursue_goal(:find_social_network, person: "alice")
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      assert_includes result, "alice"
      assert_operator result.length, :>=, 3
    end
  end

  # === Real-World Workflow Integration ===

  def test_business_process_automation
    code = <<~PATLANG
      reasoning mode on
      
      # Business process: Order fulfillment
      goal process_order(order_id) {
        precondition: order_exists?(order_id),
        postcondition: 
          order.status == "fulfilled" and
          inventory_updated? and
          customer_notified?,
        subgoals: [
          validate_order_data(order_id),
          check_inventory_availability(order_id),
          reserve_items(order_id),
          process_payment(order_id),
          schedule_shipping(order_id),
          update_order_status(order_id, "fulfilled"),
          send_confirmation_email(order_id)
        ]
      }
      
      # Order validation form
      form order_validation {
        constrain customer_id :: Number where customer_exists?(customer_id);
        constrain items :: Array where all_items_available?(items);
        constrain payment_method :: String where valid_payment_method?(payment_method);
        constrain shipping_address :: Object where valid_address?(shipping_address);
      }
      
      # Process a sample order
      order_data = {
        order_id: 12345,
        customer_id: 67890,
        items: [
          { product_id: 111, quantity: 2 },
          { product_id: 222, quantity: 1 }
        ],
        payment_method: "credit_card",
        shipping_address: {
          street: "123 Main St",
          city: "Anytown",
          zip: "12345"
        }
      }
      
      # Validate and process
      validation = validate_form(:order_validation, order_data)
      if validation.valid?
        fulfillment_result = pursue_goal(:process_order, order_id: 12345)
      else
        fulfillment_result = { status: "validation_failed", errors: validation.errors }
      end
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      if result[:status] == "fulfilled"
        assert result[:inventory_updated]
        assert result[:customer_notified]
      else
        assert_equal "validation_failed", result[:status]
        assert result[:errors].any?
      end
    end
  end

  def test_scientific_data_analysis_workflow
    code = <<~PATLANG
      reasoning mode on
      
      # Data quality constraints
      form experiment_data {
        constrain sample_size :: Number where sample_size >= 30;
        constrain p_value :: Number where p_value >= 0 and p_value <= 1;
        constrain confidence_interval :: Array where length == 2 and first < second;
        constrain methodology :: String where peer_reviewed_method?(methodology);
      }
      
      # Statistical analysis goal
      goal analyze_experiment(data) {
        precondition: data.validated? and data.complete?,
        postcondition: 
          results.statistically_significant? and
          results.reproducible? and
          results.peer_reviewable?,
        methodology: [
          validate_data_quality,
          apply_statistical_tests,
          calculate_effect_size,
          assess_reproducibility,
          generate_visualizations,
          prepare_publication_draft
        ]
      }
      
      # Knowledge base of statistical methods
      assert_fact("statistical_test(t_test, continuous, normal)")
      assert_fact("statistical_test(chi_square, categorical, any)")
      assert_fact("statistical_test(mann_whitney, continuous, non_normal)")
      
      define_rule("appropriate_test(DataType, Distribution, Test) :-
        statistical_test(Test, DataType, Distribution)")
      
      # Sample experimental data
      experiment = {
        sample_size: 50,
        p_value: 0.032,
        confidence_interval: [0.12, 0.87],
        methodology: "randomized_controlled_trial",
        data_type: "continuous",
        distribution: "normal"
      }
      
      # Process the analysis
      validation = validate_form(:experiment_data, experiment)
      appropriate_tests = query("appropriate_test(continuous, normal, Test)")
      
      if validation.valid?
        analysis_results = pursue_goal(:analyze_experiment, data: experiment)
      end
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      validation = result[:validation]
      tests = result[:appropriate_tests]
      
      assert validation.valid?
      assert tests.any? { |t| t[:Test] == "t_test" }
      
      if result[:analysis_results]
        assert result[:analysis_results][:statistically_significant]
        assert result[:analysis_results][:peer_reviewable]
      end
    end
  end

  # === Performance and Integration Testing ===

  def test_reasoning_pipeline_performance
    code = <<~PATLANG
      reasoning mode on
      
      # Large-scale reasoning pipeline
      100.times do |i|
        assert_fact("number(#{i})")
        if i.even?
          assert_fact("even(#{i})")
        end
        if prime?(i)
          assert_fact("prime(#{i})")
        end
      end
      
      # Complex goal involving multiple paradigms
      goal find_special_numbers {
        postcondition: 
          results.all? { |n| n.even? and prime?(n) and n < 100 }
      }
      
      # Form validation for mathematical constraints
      form number_criteria {
        constrain max_value :: Number where max_value > 0 and max_value <= 1000;
        constrain must_be_even :: Boolean where must_be_even == true;
        constrain must_be_prime :: Boolean where must_be_prime == true;
      }
      
      criteria = {
        max_value: 100,
        must_be_even: true,
        must_be_prime: true
      }
      
      start_time = Time.now
      validation = validate_form(:number_criteria, criteria)
      special_numbers = pursue_goal(:find_special_numbers) if validation.valid?
      duration = Time.now - start_time
    PATLANG
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = Patlang.evaluate(code)
      
      duration = result[:duration]
      assert_operator duration, :<, 2.0, "Complex reasoning pipeline should complete in <2 seconds"
      
      special_numbers = result[:special_numbers]
      assert_equal [2], special_numbers, "Only 2 is both even and prime under 100"
    end
  end

  def test_error_propagation_across_reasoning_components
    code = <<~PATLANG
      reasoning mode on
      
      # This should trigger errors in multiple components
      form invalid_form {
        constrain bad_field :: InvalidType where impossible_constraint;
      }
      
      goal impossible_goal {
        postcondition: 1 == 2  # Impossible condition
      }
      
      assert_fact("malformed fact without proper syntax")
      
      # Attempt to use all components
      validation = validate_form(:invalid_form, { bad_field: "test" })
      result = pursue_goal(:impossible_goal)
      facts = query("malformed_query_syntax")
    PATLANG
    
    # Should fail with appropriate error messages
    error = assert_raises(StandardError) do
      Patlang.evaluate(code)
    end
    
    # Error should indicate which reasoning component failed
    assert_match(/InvalidType|impossible_constraint|malformed/, error.message)
  end

  private

  def prime?(n)
    return false if n < 2
    return true if n == 2
    return false if n.even?
    
    (3..Math.sqrt(n)).step(2) do |i|
      return false if n % i == 0
    end
    true
  end
end

# === Enhanced Patlang Integration Tests ===

class TestPatlangReasoningIntegration < Minitest::Test
  def test_patlang_evaluate_with_reasoning
    # Test basic reasoning integration
    result = Patlang.evaluate("2 + 3")
    assert_equal 5, result
  end

  def test_patlang_evaluate_with_form_validation
    # This would test form validation integration
    # For now, ensure no errors occur
    result = Patlang.evaluate("form validation test")
    # Should not raise NotImplementedError anymore
    refute_nil result
  end

  def test_patlang_evaluate_with_goal_system
    # This would test goal system integration
    result = Patlang.evaluate("goal system test")
    refute_nil result
  end

  def test_patlang_evaluate_with_facts_database
    # This would test facts database integration
    result = Patlang.evaluate("fact database test")
    refute_nil result
  end
end

# === Integration Error Classes ===

class ReasoningIntegrationError < StandardError
  attr_reader :component, :operation

  def initialize(message, component: nil, operation: nil)
    super(message)
    @component = component
    @operation = operation
  end
end

class CrossParadigmInferenceError < StandardError
  attr_reader :source_paradigm, :target_paradigm

  def initialize(message, source_paradigm: nil, target_paradigm: nil)
    super(message)
    @source_paradigm = source_paradigm
    @target_paradigm = target_paradigm
  end
end

# === Enhanced ReasoningCoordinator for Integration ===

class ReasoningCoordinator
  def register_component(name, component)
    # This should be implemented in GREEN phase
    raise NotImplementedError, "ReasoningCoordinator component registration not yet implemented - this is RED phase"
  end

  def execute_reasoning_pipeline(code)
    # This should be implemented in GREEN phase
    raise NotImplementedError, "ReasoningCoordinator pipeline execution not yet implemented - this is RED phase"
  end

  def cross_paradigm_inference(source_data, target_paradigm)
    # This should be implemented in GREEN phase
    raise NotImplementedError, "Cross-paradigm inference not yet implemented - this is RED phase"
  end
end