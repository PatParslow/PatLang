#!/usr/bin/env ruby
# frozen_string_literal: true

# Build Tool Assessment Script
# Tests goal-oriented programming capabilities for build tool development

require_relative 'src/reasoning/goal_system'
require_relative 'src/reasoning/reasoning_coordinator'
require_relative 'src/reasoning/advanced_goal_strategies'

class BuildToolAssessment
  def initialize
    @coordinator = ReasoningCoordinator.new
    @goal_system = GoalSystem.new(@coordinator)
    @advanced_strategies = AdvancedGoalStrategies.new(@coordinator)
    @results = {}
  end

  def run_assessment
    puts "=" * 60
    puts "PaTLang Build Tool Capability Assessment"
    puts "=" * 60
    
    test_basic_goal_system
    test_reasoning_coordinator
    test_advanced_strategies
    test_build_specific_capabilities
    
    summarize_results
  end

  private

  def test_basic_goal_system
    puts "\n1. Testing Basic Goal System..."
    
    begin
      # Test goal declaration and pursuit
      goal = @goal_system.declare_goal(:compile_source, <<~GOAL
        goal compile_source {
          description: "Compile source files to target format"
          precondition: source_files_exist
          postcondition: compiled_files_exist
          strategy: incremental_compilation
        }
      GOAL
      )
      
      @results[:goal_declaration] = goal.name == :compile_source
      puts "  ✓ Goal declaration: #{@results[:goal_declaration] ? 'PASS' : 'FAIL'}"
      
      # Test goal pursuit
      result = @goal_system.pursue_goal(:compile_source, { source_dir: 'src' })
      @results[:goal_pursuit] = !result.nil?
      puts "  ✓ Goal pursuit: #{@results[:goal_pursuit] ? 'PASS' : 'FAIL'}"
      
    rescue => e
      puts "  ✗ Goal system error: #{e.message}"
      @results[:goal_declaration] = false
      @results[:goal_pursuit] = false
    end
  end

  def test_reasoning_coordinator
    puts "\n2. Testing Reasoning Coordinator..."
    
    begin
      # Enable reasoning mode
      @coordinator.enable_reasoning_mode
      @results[:reasoning_mode] = @coordinator.reasoning_mode_enabled?
      puts "  ✓ Reasoning mode: #{@results[:reasoning_mode] ? 'PASS' : 'FAIL'}"
      
      # Test fact assertion for build dependencies
      @coordinator.assert_fact("depends_on(main.rb, utils.rb)")
      @coordinator.assert_fact("depends_on(utils.rb, constants.rb)")
      
      facts = @coordinator.get_facts
      @results[:fact_storage] = facts.length >= 2
      puts "  ✓ Fact storage: #{@results[:fact_storage] ? 'PASS' : 'FAIL'}"
      
      # Test rule definition for build logic
      @coordinator.define_rule("needs_rebuild(File) :- depends_on(File, Dep), modified(Dep)")
      
      rules = @coordinator.get_rules
      @results[:rule_definition] = rules.length >= 1
      puts "  ✓ Rule definition: #{@results[:rule_definition] ? 'PASS' : 'FAIL'}"
      
    rescue => e
      puts "  ✗ Reasoning coordinator error: #{e.message}"
      @results[:reasoning_mode] = false
      @results[:fact_storage] = false
      @results[:rule_definition] = false
    end
  end

  def test_advanced_strategies
    puts "\n3. Testing Advanced Goal Strategies..."
    
    begin
      # Test parallel execution capability
      result = @advanced_strategies.execute_parallel_strategies(
        :parallel_compilation,
        "strategies: [compiler_gcc, compiler_clang, incremental_build]",
        { target: "optimized_build" }
      )
      
      @results[:parallel_strategies] = result[:parallel_execution][:strategies_executed] > 0
      puts "  ✓ Parallel strategies: #{@results[:parallel_strategies] ? 'PASS' : 'FAIL'}"
      
      # Test dynamic decomposition
      decomp_result = @advanced_strategies.execute_dynamic_decomposition(
        :complex_build,
        "decomposition: hierarchical",
        { system_requirements: ["compilation", "linking", "testing"] }
      )
      
      @results[:dynamic_decomposition] = decomp_result[:decomposition][:subgoals_generated] > 0
      puts "  ✓ Dynamic decomposition: #{@results[:dynamic_decomposition] ? 'PASS' : 'FAIL'}"
      
    rescue => e
      puts "  ✗ Advanced strategies error: #{e.message}"
      @results[:parallel_strategies] = false
      @results[:dynamic_decomposition] = false
    end
  end

  def test_build_specific_capabilities
    puts "\n4. Testing Build-Specific Capabilities..."
    
    begin
      # Test dependency resolution capability
      dependency_goal = @goal_system.declare_goal(:resolve_dependencies, <<~GOAL
        goal resolve_dependencies {
          description: "Resolve and order build dependencies"
          strategy: topological_sort
          postcondition: dependencies_resolved
        }
      GOAL
      )
      
      @results[:dependency_goal] = !dependency_goal.nil?
      puts "  ✓ Dependency goal creation: #{@results[:dependency_goal] ? 'PASS' : 'FAIL'}"
      
      # Test incremental build logic
      @coordinator.assert_fact("file_modified(src/main.rb, timestamp_123)")
      @coordinator.assert_fact("depends_on(build/main.o, src/main.rb)")
      
      query_result = @coordinator.query("needs_rebuild(X)")
      @results[:incremental_logic] = query_result.is_a?(Array)
      puts "  ✓ Incremental build logic: #{@results[:incremental_logic] ? 'PASS' : 'FAIL'}"
      
    rescue => e
      puts "  ✗ Build-specific capabilities error: #{e.message}"
      @results[:dependency_goal] = false
      @results[:incremental_logic] = false
    end
  end

  def summarize_results
    puts "\n" + "=" * 60
    puts "ASSESSMENT SUMMARY"
    puts "=" * 60
    
    total_tests = @results.length
    passed_tests = @results.values.count(true)
    
    puts "\nCore Capabilities:"
    puts "  Goal Declaration: #{status(@results[:goal_declaration])}"
    puts "  Goal Pursuit: #{status(@results[:goal_pursuit])}"
    puts "  Reasoning Mode: #{status(@results[:reasoning_mode])}"
    puts "  Fact Storage: #{status(@results[:fact_storage])}"
    puts "  Rule Definition: #{status(@results[:rule_definition])}"
    
    puts "\nAdvanced Features:"
    puts "  Parallel Strategies: #{status(@results[:parallel_strategies])}"
    puts "  Dynamic Decomposition: #{status(@results[:dynamic_decomposition])}"
    
    puts "\nBuild Tool Readiness:"
    puts "  Dependency Goals: #{status(@results[:dependency_goal])}"
    puts "  Incremental Logic: #{status(@results[:incremental_logic])}"
    
    puts "\nOverall Assessment:"
    puts "  Tests Passed: #{passed_tests}/#{total_tests}"
    puts "  Success Rate: #{(passed_tests.to_f / total_tests * 100).round(1)}%"
    
    if passed_tests >= total_tests * 0.8
      puts "  Readiness: ✓ READY for build tool implementation"
    elsif passed_tests >= total_tests * 0.6
      puts "  Readiness: ⚠ PARTIALLY READY - minor enhancements needed"
    else
      puts "  Readiness: ✗ NOT READY - significant work required"
    end
    
    puts "\nRecommendations:"
    generate_recommendations
  end

  def status(result)
    result ? "✓ WORKING" : "✗ NEEDS WORK"
  end

  def generate_recommendations
    if @results[:goal_declaration] && @results[:reasoning_mode]
      puts "  • Goal-oriented foundation is solid"
    end
    
    if @results[:parallel_strategies]
      puts "  • Parallel execution ready for multi-core builds"
    end
    
    if @results[:dynamic_decomposition]
      puts "  • Complex build decomposition capabilities available"
    end
    
    unless @results[:incremental_logic]
      puts "  • Enhance dependency tracking and incremental build logic"
    end
    
    puts "  • Consider implementing build-specific goal types"
    puts "  • Add file system monitoring capabilities"
    puts "  • Integrate with existing build tools (make, rake equivalents)"
  end
end

# Run the assessment
if __FILE__ == $0
  assessment = BuildToolAssessment.new
  assessment.run_assessment
end