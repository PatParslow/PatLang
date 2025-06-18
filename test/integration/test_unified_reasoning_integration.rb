# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/reasoning_coordinator'
require_relative '../../src/reasoning/goal_system'
require_relative '../../patlang-core/evaluator/evaluator'

# Comprehensive integration tests for the unified reasoning system
class TestUnifiedReasoningIntegration < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    @reasoning_coordinator = ReasoningCoordinator.new(@evaluator)
    @goal_system = GoalSystem.new(@evaluator)
    @goal_system.set_reasoning_coordinator(@reasoning_coordinator)
    @event_log = []
    
    # Subscribe to all reasoning events
    @reasoning_coordinator.on_event(:reasoning_mode_enabled) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:constraint_declared) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:goal_created) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:inference_completed) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:fact_asserted) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:query_executed) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:type_refined) { |e| @event_log << e }
    
    @goal_system.on_event(:goal_declared) { |e| @event_log << e }
    @goal_system.on_event(:goal_achieved) { |e| @event_log << e }
    @goal_system.on_event(:concurrent_goals_completed) { |e| @event_log << e }
    
    @evaluator.enable_object_mode
    @reasoning_coordinator.enable_reasoning_mode
  end

  # === End-to-End Reasoning Scenarios ===

  def test_complete_constraint_goal_logic_integration
    # Scenario: Smart home temperature control system
    
    # 1. Define type constraints for sensor data
    @reasoning_coordinator.create_constraint(:temperature, :type, :Number)
    @reasoning_coordinator.create_constraint(:temperature, :range, -40..60)
    @reasoning_coordinator.create_constraint(:humidity, :type, :Number)
    @reasoning_coordinator.create_constraint(:humidity, :range, 0..100)
    @reasoning_coordinator.create_constraint(:room_id, :type, :Symbol)
    
    # 2. Assert facts about the smart home system
    @reasoning_coordinator.assert_fact("room(living_room)")
    @reasoning_coordinator.assert_fact("room(bedroom)")
    @reasoning_coordinator.assert_fact("room(kitchen)")
    @reasoning_coordinator.assert_fact("sensor(temp_sensor_1, living_room)")
    @reasoning_coordinator.assert_fact("sensor(temp_sensor_2, bedroom)")
    @reasoning_coordinator.assert_fact("sensor(humidity_sensor_1, living_room)")
    @reasoning_coordinator.assert_fact("reading(temp_sensor_1, 22)")
    @reasoning_coordinator.assert_fact("reading(temp_sensor_2, 18)")
    @reasoning_coordinator.assert_fact("reading(humidity_sensor_1, 45)")
    @reasoning_coordinator.assert_fact("target_temp(living_room, 21)")
    @reasoning_coordinator.assert_fact("target_temp(bedroom, 19)")
    
    # 3. Define logical rules for the system
    @reasoning_coordinator.define_rule("comfortable_temp(Room, Temp) :- target_temp(Room, Target), Temp >= Target - 2, Temp <= Target + 2")
    @reasoning_coordinator.define_rule("needs_heating(Room) :- sensor(Sensor, Room), reading(Sensor, Temp), target_temp(Room, Target), Temp < Target - 1")
    @reasoning_coordinator.define_rule("needs_cooling(Room) :- sensor(Sensor, Room), reading(Sensor, Temp), target_temp(Room, Target), Temp > Target + 1")
    @reasoning_coordinator.define_rule("optimal_humidity(Room) :- sensor(Sensor, Room), reading(Sensor, Humidity), Humidity >= 40, Humidity <= 60")
    
    # 4. Define goals for climate control
    @goal_system.declare_goal(:optimize_climate, <<~GOAL
      goal optimize_climate {
        description: "Optimize room climate based on sensor data and targets"
        parameters: [room, current_temp, target_temp]
        precondition: room != null
        precondition: current_temp.is_a?(Number)
        postcondition: result.is_a?(Symbol)
      }
    GOAL
    )
    
    @goal_system.declare_goal(:find_comfortable_rooms, <<~GOAL
      goal find_comfortable_rooms {
        description: "Find all rooms with comfortable temperature"
        postcondition: result.is_a?(Array)
      }
    GOAL
    )
    
    # 5. Execute integrated reasoning
    
    # Query for rooms needing heating
    heating_query = @reasoning_coordinator.query("needs_heating(X)")
    assert_instance_of Array, heating_query
    
    # Query for comfortable temperatures
    comfort_query = @reasoning_coordinator.query("comfortable_temp(living_room, X)")
    assert_instance_of Array, comfort_query
    
    # Pursue climate optimization goal
    optimization_result = @goal_system.pursue_goal(:optimize_climate, 
      room: :living_room, 
      current_temp: 22, 
      target_temp: 21
    )
    assert_instance_of Integer, optimization_result
    
    # Pursue room finding goal
    rooms_result = @goal_system.pursue_goal(:find_comfortable_rooms)
    assert_instance_of Integer, rooms_result
    
    # 6. Validate constraints are satisfied
    assert @reasoning_coordinator.constraint_system.variable_satisfies?(:temperature, 22)
    assert @reasoning_coordinator.constraint_system.variable_satisfies?(:humidity, 45)
    refute @reasoning_coordinator.constraint_system.variable_satisfies?(:temperature, 100)
    
    # 7. Verify event propagation
    assert_events_include :constraint_declared
    assert_events_include :fact_asserted
    assert_events_include :goal_declared
    assert_events_include :goal_achieved
    assert_events_include :query_executed
    assert_events_include :inference_completed
  end

  def test_complex_multi_paradigm_reasoning_scenario
    # Scenario: Academic course recommendation system
    
    # 1. Type constraints for academic data
    @reasoning_coordinator.create_constraint(:student_id, :type, :Symbol)
    @reasoning_coordinator.create_constraint(:course_code, :pattern, /\A[A-Z]{2,4}\d{3}\z/)
    @reasoning_coordinator.create_constraint(:grade, :type, :Number)
    @reasoning_coordinator.create_constraint(:grade, :range, 0..100)
    @reasoning_coordinator.create_constraint(:credit_hours, :type, :Number)
    @reasoning_coordinator.create_constraint(:credit_hours, :range, 1..6)
    
    # 2. Student and course facts
    students = [:alice, :bob, :charlie, :diana]
    courses = ["CS101", "CS201", "MATH150", "PHYS101", "ENG100"]
    
    students.each { |student| @reasoning_coordinator.assert_fact("student(#{student})") }
    courses.each { |course| @reasoning_coordinator.assert_fact("course(#{course})") }
    
    # Enrollment and grade facts
    enrollments = [
      ["alice", "CS101", 95], ["alice", "MATH150", 88], ["alice", "ENG100", 92],
      ["bob", "CS101", 78], ["bob", "PHYS101", 85], ["bob", "ENG100", 76],
      ["charlie", "MATH150", 92], ["charlie", "PHYS101", 89], ["charlie", "CS101", 88],
      ["diana", "CS201", 94], ["diana", "CS101", 96], ["diana", "MATH150", 90]
    ]
    
    enrollments.each do |student, course, grade|
      @reasoning_coordinator.assert_fact("enrolled(#{student}, #{course})")
      @reasoning_coordinator.assert_fact("grade(#{student}, #{course}, #{grade})")
      @reasoning_coordinator.assert_fact("credit_hours(#{course}, 3)")
    end
    
    # Prerequisites and course relationships
    @reasoning_coordinator.assert_fact("prerequisite(CS201, CS101)")
    @reasoning_coordinator.assert_fact("difficulty(CS101, beginner)")
    @reasoning_coordinator.assert_fact("difficulty(CS201, intermediate)")
    @reasoning_coordinator.assert_fact("difficulty(MATH150, intermediate)")
    @reasoning_coordinator.assert_fact("department(CS101, computer_science)")
    @reasoning_coordinator.assert_fact("department(CS201, computer_science)")
    @reasoning_coordinator.assert_fact("department(MATH150, mathematics)")
    
    # 3. Academic rules
    academic_rules = [
      "passed(Student, Course) :- grade(Student, Course, Grade), Grade >= 70",
      "honor_student(Student) :- grade(Student, Course, Grade), Grade >= 90",
      "eligible_for(Student, Course) :- prerequisite(Course, Prereq), passed(Student, Prereq)",
      "gpa(Student, GPA) :- student(Student), enrolled(Student, _)",  # Simplified GPA calculation
      "major_match(Student, Department) :- enrolled(Student, Course), department(Course, Department)",
      "high_performer(Student, Subject) :- grade(Student, Course, Grade), department(Course, Subject), Grade >= 85",
      "course_load(Student, Total) :- student(Student), enrolled(Student, _)"  # Simplified course load
    ]
    
    academic_rules.each { |rule| @reasoning_coordinator.define_rule(rule) }
    
    # 4. Academic recommendation goals
    @goal_system.declare_goal(:recommend_courses, <<~GOAL
      goal recommend_courses {
        description: "Recommend courses for a student based on performance and prerequisites"
        parameters: [student_id, preferred_department]
        precondition: student_id != null
        postcondition: result.is_a?(Array) || result.is_a?(Symbol)
      }
    GOAL
    )
    
    @goal_system.declare_goal(:find_top_students, <<~GOAL
      goal find_top_students {
        description: "Find top performing students"
        postcondition: result.is_a?(Array) || result.is_a?(Symbol)
      }
    GOAL
    )
    
    @goal_system.declare_goal(:analyze_academic_performance, <<~GOAL
      goal analyze_academic_performance {
        description: "Analyze overall academic performance metrics"
        postcondition: result.is_a?(Hash) || result.is_a?(Symbol) || result.is_a?(Integer)
      }
    GOAL
    )
    
    # 5. Execute comprehensive reasoning
    
    # Logic programming queries
    passed_students = @reasoning_coordinator.query("passed(alice, X)")
    honor_students = @reasoning_coordinator.query("honor_student(X)")
    eligible_for_cs201 = @reasoning_coordinator.query("eligible_for(X, CS201)")
    cs_majors = @reasoning_coordinator.query("major_match(X, computer_science)")
    
    assert_instance_of Array, passed_students
    assert_instance_of Array, honor_students
    assert_instance_of Array, eligible_for_cs201
    assert_instance_of Array, cs_majors
    
    # Goal-oriented reasoning
    course_recommendations = @goal_system.pursue_goal(:recommend_courses, 
      student_id: :alice, 
      preferred_department: :computer_science
    )
    
    top_students = @goal_system.pursue_goal(:find_top_students)
    performance_analysis = @goal_system.pursue_goal(:analyze_academic_performance)
    
    # Validate results have appropriate types
    assert [Array, Symbol, Integer].any? { |klass| course_recommendations.is_a?(klass) }
    assert [Array, Symbol, Integer].any? { |klass| top_students.is_a?(klass) }
    assert [Hash, Symbol, Integer].any? { |klass| performance_analysis.is_a?(klass) }
    
    # 6. Constraint validation for academic data
    assert @reasoning_coordinator.constraint_system.variable_satisfies?(:grade, 95)
    assert @reasoning_coordinator.constraint_system.variable_satisfies?(:credit_hours, 3)
    refute @reasoning_coordinator.constraint_system.variable_satisfies?(:grade, 150)
    refute @reasoning_coordinator.constraint_system.variable_satisfies?(:credit_hours, 10)
    
    # 7. Cross-paradigm integration verification
    
    # Type inference from facts
    @reasoning_coordinator.assert_fact("typeof(grade, number)")
    inferred_type = @reasoning_coordinator.infer_type_from_facts(:grade)
    assert_equal :Number, inferred_type
    
    # Constraint propagation to logic
    grade_constraint = @reasoning_coordinator.get_constraint(:grade)
    @reasoning_coordinator.propagate_constraint_to_logic(:grade, grade_constraint)
    
    facts = @reasoning_coordinator.get_facts
    assert_includes facts, "typeof(grade, Number)"
    assert_includes facts, "range(grade, 0, 100)"
  end

  def test_concurrent_reasoning_integration
    # Test concurrent execution of multiple reasoning paradigms
    
    @reasoning_coordinator.create_constraint(:concurrent_var, :type, :Number)
    @reasoning_coordinator.create_constraint(:concurrent_var, :range, 1..100)
    
    # Define multiple goals for concurrent execution
    goal_definitions = [
      [:concurrent_goal_a, "Find even number in range"],
      [:concurrent_goal_b, "Find prime number in range"],
      [:concurrent_goal_c, "Find perfect square in range"],
      [:concurrent_goal_d, "Find multiple of 7 in range"]
    ]
    
    goal_definitions.each do |name, description|
      @goal_system.declare_goal(name, <<~GOAL
        goal #{name} {
          description: "#{description}"
          postcondition: result.is_a?(Integer)
          postcondition: result >= 1
          postcondition: result <= 100
        }
      GOAL
      )
    end
    
    # Execute goals concurrently
    goal_names = goal_definitions.map(&:first)
    start_time = Time.now
    
    concurrent_results = @goal_system.pursue_goals_concurrently(goal_names)
    
    duration = Time.now - start_time
    
    # Verify concurrent execution results
    assert_instance_of Array, concurrent_results
    assert_equal goal_names.length, concurrent_results.length
    
    # All results should be integers in the valid range
    concurrent_results.each do |result|
      assert_instance_of Integer, result
      assert_operator result, :>=, 1
      assert_operator result, :<=, 100
      assert @reasoning_coordinator.constraint_system.variable_satisfies?(:concurrent_var, result)
    end
    
    # Concurrent execution should be reasonably fast
    assert_operator duration, :<, 2.0, "Concurrent reasoning should complete in reasonable time"
    
    # Verify events for concurrent completion
    assert_events_include :concurrent_goals_completed
  end

  def test_reasoning_system_resilience_and_recovery
    # Test system behavior under stress and error conditions
    
    # 1. Create a large knowledge base
    1000.times do |i|
      @reasoning_coordinator.assert_fact("large_fact_#{i}(data_#{i})")
      
      if i % 100 == 0
        @reasoning_coordinator.define_rule("large_rule_#{i}(X) :- large_fact_#{i}(X)")
      end
      
      if i % 200 == 0
        @reasoning_coordinator.create_constraint("large_var_#{i}".to_sym, :type, :Number)
      end
    end
    
    # 2. Test system still functions correctly
    facts_count = @reasoning_coordinator.get_facts.length
    rules_count = @reasoning_coordinator.get_rules.length
    stats = @reasoning_coordinator.statistics
    
    assert_operator facts_count, :>=, 1000
    assert_operator rules_count, :>=, 10
    assert_operator stats[:constraints], :>=, 5
    
    # 3. Test query performance on large dataset
    start_time = Time.now
    query_results = @reasoning_coordinator.query("large_fact_500(X)")
    query_duration = Time.now - start_time
    
    assert_instance_of Array, query_results
    assert_operator query_duration, :<, 0.1, "Queries should remain fast on large datasets"
    
    # 4. Test goal execution under load
    @goal_system.declare_goal(:stress_test_goal, <<~GOAL
      goal stress_test_goal {
        description: "Goal executed under system stress"
        postcondition: result.is_a?(Integer)
      }
    GOAL
    )
    
    start_time = Time.now
    stress_result = @goal_system.pursue_goal(:stress_test_goal)
    stress_duration = Time.now - start_time
    
    assert_instance_of Integer, stress_result
    assert_operator stress_duration, :<, 0.5, "Goals should execute efficiently under load"
    
    # 5. Test system recovery after reset
    initial_stats = @reasoning_coordinator.statistics
    
    @reasoning_coordinator.reset!
    
    reset_stats = @reasoning_coordinator.statistics
    assert_equal 0, reset_stats[:facts]
    assert_equal 0, reset_stats[:rules]
    assert_equal 0, reset_stats[:goals]
    assert_equal 0, reset_stats[:constraints]
    
    # 6. Verify system can be rebuilt after reset
    @reasoning_coordinator.enable_reasoning_mode
    @reasoning_coordinator.create_constraint(:recovery_var, :type, :String)
    @reasoning_coordinator.assert_fact("recovery_fact(data)")
    @reasoning_coordinator.create_goal(:recovery_goal, description: "Recovery test goal")
    
    recovery_result = @reasoning_coordinator.pursue_goal(:recovery_goal)
    assert_instance_of Integer, recovery_result
  end

  def test_comprehensive_performance_integration
    # Comprehensive performance test across all reasoning paradigms
    
    operations_count = 50
    
    start_time = Time.now
    
    operations_count.times do |i|
      # Type constraints
      @reasoning_coordinator.create_constraint("perf_var_#{i}".to_sym, :type, :Number)
      @reasoning_coordinator.create_constraint("perf_var_#{i}".to_sym, :range, 0..1000)
      
      # Logic programming
      @reasoning_coordinator.assert_fact("perf_entity(entity_#{i})")
      @reasoning_coordinator.assert_fact("perf_property(entity_#{i}, value_#{i})")
      
      if i % 5 == 0
        @reasoning_coordinator.define_rule("perf_rule_#{i}(X) :- perf_entity(X), perf_property(X, _)")
      end
      
      # Goal-oriented programming
      @goal_system.declare_goal("perf_goal_#{i}".to_sym, <<~GOAL
        goal perf_goal_#{i} {
          description: "Performance test goal #{i}"
          postcondition: result.is_a?(Integer)
        }
      GOAL
      )
      
      # Goal execution
      @goal_system.pursue_goal("perf_goal_#{i}".to_sym)
      
      # Queries
      if i % 10 == 0
        @reasoning_coordinator.query("perf_entity(X)")
      end
      
      # Constraint validation
      @reasoning_coordinator.constraint_system.variable_satisfies?("perf_var_#{i}".to_sym, i * 10)
    end
    
    total_duration = Time.now - start_time
    
    # Performance assertions
    avg_operation_time = total_duration / (operations_count * 6)  # 6 operations per iteration
    assert_operator avg_operation_time, :<, 0.01, "Average operation time should be < 10ms"
    assert_operator total_duration, :<, 5.0, "Total comprehensive test should complete in < 5s"
    
    # Verify system state
    final_stats = @reasoning_coordinator.statistics
    assert_operator final_stats[:constraints], :>=, operations_count
    assert_operator final_stats[:facts], :>=, operations_count * 2
    assert_operator final_stats[:goals], :>=, operations_count
    assert_operator final_stats[:inferences], :>=, operations_count
  end

  def test_event_system_comprehensive_integration
    # Test that all components properly generate and handle events
    
    @reasoning_coordinator.create_constraint(:event_var, :type, :Number)
    @reasoning_coordinator.assert_fact("event_fact(data)")
    @reasoning_coordinator.define_rule("event_rule(X) :- event_fact(X)")
    @reasoning_coordinator.create_goal(:event_goal, description: "Event test goal")
    @reasoning_coordinator.pursue_goal(:event_goal)
    @reasoning_coordinator.query("event_fact(X)")
    
    # Verify all expected event types were fired
    expected_events = [
      :reasoning_mode_enabled,
      :constraint_declared,
      :fact_asserted,
      :rule_defined,
      :goal_created,
      :inference_completed,
      :query_executed
    ]
    
    actual_event_types = @event_log.map { |e| e[:event_type] }.uniq
    
    expected_events.each do |expected_event|
      assert_includes actual_event_types, expected_event,
                     "Expected event #{expected_event} to be fired"
    end
    
    # Verify event data completeness
    constraint_events = @event_log.select { |e| e[:event_type] == :constraint_declared }
    assert constraint_events.any?
    assert constraint_events.all? { |e| e.key?(:variable) && e.key?(:constraint_type) }
    
    fact_events = @event_log.select { |e| e[:event_type] == :fact_asserted }
    assert fact_events.any?
    assert fact_events.all? { |e| e.key?(:fact) && e.key?(:total_facts) }
    
    goal_events = @event_log.select { |e| e[:event_type] == :goal_created }
    assert goal_events.any?
    assert goal_events.all? { |e| e.key?(:name) && e.key?(:goal) }
    
    inference_events = @event_log.select { |e| e[:event_type] == :inference_completed }
    assert inference_events.any?
    assert inference_events.all? { |e| e.key?(:result) && e.key?(:success) }
  end

  private

  def assert_events_include(event_type)
    event_types = @event_log.map { |e| e[:event_type] }
    assert_includes event_types, event_type,
                   "Expected events to include #{event_type}"
  end
end