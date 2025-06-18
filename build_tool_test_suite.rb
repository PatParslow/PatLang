#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive Test Suite for PaTLang Build Tool
# Tests functionality, error handling, and edge cases

require_relative 'build_tool/core/build_runner'
require_relative 'build_tool/dsl/build_dsl'
require 'fileutils'

class BuildToolTestSuite
  def initialize
    @test_results = []
    @failures = []
  end

  def run_all_tests
    puts "🧪 PaTLang Build Tool - Comprehensive Test Suite"
    puts "=" * 60
    
    # Core functionality tests
    test_basic_target_definition
    test_dependency_resolution
    test_parallel_execution
    test_dsl_functionality
    test_error_handling
    test_integration_with_reasoning
    test_cli_interface
    test_edge_cases
    
    generate_test_report
  end

  private

  def test_basic_target_definition
    test_section("Basic Target Definition")
    
    runner = BuildRunner.new
    
    # Test simple target definition
    assert_no_error "Simple target definition" do
      runner.define_target(:test_target,
        target_type: :compile,
        command: "echo 'test'"
      )
    end
    
    # Test target with dependencies
    assert_no_error "Target with dependencies" do
      runner.define_target(:dependent_target,
        target_type: :test,
        dependencies: [:test_target],
        command: "echo 'dependent'"
      )
    end
    
    # Verify targets are registered
    assert_equal "Target registration", 2, runner.build_targets.length
  end

  def test_dependency_resolution
    test_section("Dependency Resolution")
    
    runner = BuildRunner.new
    
    # Create complex dependency chain
    runner.define_target(:a, command: "echo a")
    runner.define_target(:b, dependencies: [:a], command: "echo b")
    runner.define_target(:c, dependencies: [:a], command: "echo c")
    runner.define_target(:d, dependencies: [:b, :c], command: "echo d")
    
    # Test dependency graph generation
    graph = runner.dependency_graph
    assert_equal "Dependency graph size", 4, graph.length
    assert_includes "Dependency resolution", graph[:d], :b
    assert_includes "Dependency resolution", graph[:d], :c
  end

  def test_parallel_execution
    test_section("Parallel Execution")
    
    runner = BuildRunner.new
    
    # Create parallel-safe targets
    (1..3).each do |i|
      runner.define_target("parallel_#{i}".to_sym,
        parallel_safe: true,
        command: proc { |target, context|
          sleep(0.01) # Simulate work
          "Parallel task #{i} completed"
        }
      )
    end
    
    # Test parallel execution
    start_time = Time.now
    result = runner.build([:parallel_1, :parallel_2, :parallel_3])
    end_time = Time.now
    
    assert_true "Parallel execution completed", result[:status] != :failure
    assert_true "Execution time reasonable", (end_time - start_time) < 1.0
  end

  def test_dsl_functionality
    test_section("DSL Functionality")
    
    # Test basic DSL usage
    assert_no_error "Basic DSL build" do
      result = BuildDSL.quick_build do
        var :test_var, "test_value"
        
        compile :dsl_test do
          description "DSL test target"
          action { |target, context| "DSL working" }
        end
        
        default :dsl_test
      end
      
      assert_equal "DSL build status", :partial_failure, result[:status]
    end
    
    # Test variable access
    build_file = BuildDSL::BuildFile.new(BuildRunner.new)
    build_file.var(:test_var, "test_value")
    assert_equal "Variable access", "test_value", build_file.get_var(:test_var)
  end

  def test_error_handling
    test_section("Error Handling")
    
    runner = BuildRunner.new
    
    # Test circular dependency detection
    assert_error "Circular dependency detection" do
      runner.define_target(:circular_a, dependencies: [:circular_b], command: "echo a")
      runner.define_target(:circular_b, dependencies: [:circular_a], command: "echo b")
      runner.build([:circular_a])
    end
    
    # Test missing dependency
    assert_error "Missing dependency handling" do
      runner.define_target(:missing_dep, dependencies: [:nonexistent], command: "echo test")
      runner.build([:missing_dep])
    end
    
    # Test invalid target type
    assert_no_error "Invalid target type handling" do
      runner.define_target(:invalid_type, target_type: :unknown, command: "echo test")
    end
  end

  def test_integration_with_reasoning
    test_section("Integration with PaTLang Reasoning System")
    
    runner = BuildRunner.new
    
    # Test reasoning coordinator integration
    assert_no_error "Reasoning coordinator initialization" do
      runner.reasoning_coordinator.enable_reasoning_mode
    end
    
    # Test fact assertion
    assert_no_error "Fact assertion" do
      runner.reasoning_coordinator.assert_fact("test_fact(true)")
    end
    
    # Test goal strategies
    assert_no_error "Goal strategies integration" do
      runner.define_target(:reasoning_target,
        strategy: :performance_optimized,
        command: proc { |target, context|
          { reasoning_used: true, optimization: "applied" }
        }
      )
    end
  end

  def test_cli_interface
    test_section("CLI Interface")
    
    # Test help command
    result = `ruby build_tool/patlang_build.rb --help 2>&1`
    assert_true "Help command works", result.include?("PaTLang Build Tool")
    
    # Test version command
    result = `ruby build_tool/patlang_build.rb --version 2>&1`
    assert_true "Version command works", result.include?("v1.0.0")
    
    # Test demo command
    result = `ruby build_tool/patlang_build.rb --demo 2>&1`
    assert_true "Demo command works", $?.exitstatus == 0
  end

  def test_edge_cases
    test_section("Edge Cases")
    
    runner = BuildRunner.new
    
    # Test empty target list
    result = runner.build([])
    assert_equal "Empty target list", :success, result[:status]
    
    # Test duplicate target definition
    assert_no_error "Duplicate target handling" do
      runner.define_target(:duplicate, command: "echo first")
      runner.define_target(:duplicate, command: "echo second")
    end
    
    # Test target with no command
    assert_no_error "Target with no command" do
      runner.define_target(:no_command, target_type: :generic)
    end
  end

  # Test helper methods
  def test_section(name)
    puts "\n📋 Testing: #{name}"
    puts "-" * 40
  end

  def assert_no_error(description, &block)
    begin
      block.call
      @test_results << { test: description, status: :pass }
      puts "✅ #{description}"
    rescue => e
      @test_results << { test: description, status: :fail, error: e.message }
      @failures << { test: description, error: e }
      puts "❌ #{description}: #{e.message}"
    end
  end

  def assert_error(description, &block)
    begin
      block.call
      @test_results << { test: description, status: :fail, error: "Expected error but none occurred" }
      @failures << { test: description, error: "Expected error but none occurred" }
      puts "❌ #{description}: Expected error but none occurred"
    rescue => e
      @test_results << { test: description, status: :pass }
      puts "✅ #{description}: Correctly caught error (#{e.class})"
    end
  end

  def assert_equal(description, expected, actual)
    if expected == actual
      @test_results << { test: description, status: :pass }
      puts "✅ #{description}"
    else
      @test_results << { test: description, status: :fail, error: "Expected #{expected}, got #{actual}" }
      @failures << { test: description, error: "Expected #{expected}, got #{actual}" }
      puts "❌ #{description}: Expected #{expected}, got #{actual}"
    end
  end

  def assert_true(description, condition)
    if condition
      @test_results << { test: description, status: :pass }
      puts "✅ #{description}"
    else
      @test_results << { test: description, status: :fail, error: "Condition was false" }
      @failures << { test: description, error: "Condition was false" }
      puts "❌ #{description}: Condition was false"
    end
  end

  def assert_includes(description, collection, item)
    if collection.include?(item)
      @test_results << { test: description, status: :pass }
      puts "✅ #{description}"
    else
      @test_results << { test: description, status: :fail, error: "#{item} not found in collection" }
      @failures << { test: description, error: "#{item} not found in collection" }
      puts "❌ #{description}: #{item} not found in collection"
    end
  end

  def generate_test_report
    puts "\n" + "=" * 60
    puts "🧪 TEST SUITE RESULTS"
    puts "=" * 60
    
    passed = @test_results.count { |r| r[:status] == :pass }
    failed = @test_results.count { |r| r[:status] == :fail }
    total = @test_results.length
    
    puts "📊 Summary:"
    puts "   Total Tests: #{total}"
    puts "   Passed: #{passed}"
    puts "   Failed: #{failed}"
    puts "   Success Rate: #{((passed.to_f / total) * 100).round(1)}%"
    
    if @failures.any?
      puts "\n❌ Failures:"
      @failures.each do |failure|
        puts "   • #{failure[:test]}: #{failure[:error]}"
      end
    end
    
    puts "\n🎯 Overall Assessment:"
    if failed == 0
      puts "   ✅ All tests passed! Build tool is fully functional."
    elsif failed < total * 0.1
      puts "   ⚠️  Minor issues detected but core functionality works."
    else
      puts "   ❌ Significant issues detected. Review required."
    end
    
    {
      total: total,
      passed: passed,
      failed: failed,
      success_rate: (passed.to_f / total) * 100,
      failures: @failures
    }
  end
end

# Run the test suite
if __FILE__ == $0
  test_suite = BuildToolTestSuite.new
  test_suite.run_all_tests
end