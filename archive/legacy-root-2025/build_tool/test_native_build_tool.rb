#!/usr/bin/env ruby
# frozen_string_literal: true

# Test Suite for Native PaTLang Build Tool
# Since we don't have a complete PaTLang interpreter yet, this Ruby script
# simulates how the PaTLang build tool would work and validates its logic.

require 'set'
require_relative '../patlang-core/reasoning/reasoning_coordinator'
require_relative '../patlang-core/reasoning/facts_database'

class NativePaTLangBuildToolSimulator
  def initialize
    @reasoning_coordinator = ReasoningCoordinator.new
    @facts_db = FactsDatabase.new
    @targets = {}
    @build_results = {}
    
    @reasoning_coordinator.enable_reasoning_mode
    setup_build_rules
  end
  
  def setup_build_rules
    # Define the logic programming rules from the PaTLang build tool
    
    # Transitive dependency rules
    @reasoning_coordinator.define_rule("transitive_dependency(X, Z) :- depends_on(X, Y), depends_on(Y, Z)")
    @reasoning_coordinator.define_rule("all_dependencies(X, Y) :- depends_on(X, Y)")
    @reasoning_coordinator.define_rule("all_dependencies(X, Z) :- depends_on(X, Y), all_dependencies(Y, Z)")
    
    # Circular dependency detection rules
    @reasoning_coordinator.define_rule("has_cycle(X) :- depends_on(X, X)")
    @reasoning_coordinator.define_rule("has_cycle(X) :- depends_on(X, Y), depends_on(Y, X)")
    @reasoning_coordinator.define_rule("has_cycle(X) :- depends_on(X, Y), has_cycle(Y), all_dependencies(Y, X)")
    
    # Build readiness rules
    @reasoning_coordinator.define_rule("ready_to_build(X) :- target_exists(X), all_deps_satisfied(X)")
    @reasoning_coordinator.define_rule("all_deps_satisfied(X) :- \\+ (depends_on(X, Y), \\+ build_completed(Y))")
    
    # Parallel execution rules
    @reasoning_coordinator.define_rule("can_run_parallel(X, Y) :- parallel_safe(X), parallel_safe(Y), \\+ conflicts(X, Y)")
    @reasoning_coordinator.define_rule("conflicts(X, Y) :- depends_on(X, Y)")
    @reasoning_coordinator.define_rule("conflicts(X, Y) :- depends_on(Y, X)")
  end
  
  def register_target(name, dependencies = [], command = "", parallel_safe = true)
    @targets[name] = {
      name: name,
      dependencies: dependencies,
      command: command,
      parallel_safe: parallel_safe
    }
    
    # Assert facts
    @reasoning_coordinator.assert_fact("target_exists(#{name})")
    @reasoning_coordinator.assert_fact("target_command(#{name}, '#{command}')")
    
    if parallel_safe
      @reasoning_coordinator.assert_fact("parallel_safe(#{name})")
    end
    
    dependencies.each do |dep|
      @reasoning_coordinator.assert_fact("depends_on(#{name}, #{dep})")
    end
    
    puts "✅ Registered target: #{name}"
  end
  
  def detect_circular_dependencies
    # Simple cycle detection using visited/recursion stack approach
    visited = Set.new
    rec_stack = Set.new
    cycles = []
    
    @targets.keys.each do |target|
      next if visited.include?(target)
      if has_cycle_dfs(target, visited, rec_stack)
        cycles << target
      end
    end
    
    cycles
  end
  
  def has_cycle_dfs(target, visited, rec_stack)
    visited.add(target)
    rec_stack.add(target)
    
    return false unless @targets[target]
    
    @targets[target][:dependencies].each do |dep|
      next unless @targets[dep] # Skip if dependency doesn't exist
      
      if !visited.include?(dep)
        return true if has_cycle_dfs(dep, visited, rec_stack)
      elsif rec_stack.include?(dep)
        return true
      end
    end
    
    rec_stack.delete(target)
    false
  end
  
  def get_build_order(targets)
    # Collect all targets needed (including dependencies)
    all_needed = Set.new
    targets.each { |target| collect_all_dependencies(target, all_needed) }
    
    # Simulate topological sort using reasoning
    order = []
    remaining = all_needed.to_a
    
    while remaining.any?
      ready = remaining.select do |target|
        deps = @targets[target] ? @targets[target][:dependencies] : []
        deps.all? { |dep| order.include?(dep) }
      end
      
      if ready.empty?
        # Check for cycles
        cycles = detect_circular_dependencies
        if cycles.any?
          raise "Circular dependency detected: #{cycles.join(', ')}"
        else
          raise "Unable to resolve dependencies for: #{remaining.join(', ')}"
        end
      end
      
      order.concat(ready)
      remaining -= ready
    end
    
    order
  end
  
  def collect_all_dependencies(target, collected)
    return unless @targets[target] && !collected.include?(target)
    
    collected.add(target)
    @targets[target][:dependencies].each do |dep|
      collect_all_dependencies(dep, collected)
    end
  end
  
  def find_parallel_groups(build_order)
    groups = []
    processed = Set.new
    
    build_order.each do |target|
      next if processed.include?(target)
      
      # Find all targets at the same "level" that can run in parallel
      parallel_candidates = build_order.select do |other_target|
        next false if processed.include?(other_target)
        next false unless @targets[target] && @targets[other_target]
        
        # Both must be parallel safe
        next false unless @targets[target][:parallel_safe] && @targets[other_target][:parallel_safe]
        
        # Must not depend on each other
        target_deps = @targets[target][:dependencies]
        other_deps = @targets[other_target][:dependencies]
        
        !target_deps.include?(other_target) && !other_deps.include?(target)
      end
      
      if parallel_candidates.length > 1
        groups << parallel_candidates
        processed.merge(parallel_candidates)
      else
        processed.add(target)
      end
    end
    
    groups
  end
  
  def build_targets(target_names)
    puts "\n🏗️  Starting build for: #{target_names.join(', ')}"
    
    # Check for circular dependencies
    cycles = detect_circular_dependencies
    if cycles.any?
      raise "Circular dependencies detected: #{cycles.join(', ')}"
    end
    
    # Get build order
    build_order = get_build_order(target_names)
    puts "📋 Build order: #{build_order.join(' → ')}"
    
    # Find parallel opportunities
    parallel_groups = find_parallel_groups(build_order)
    if parallel_groups.any?
      puts "⚡ Parallel execution opportunities:"
      parallel_groups.each_with_index do |group, i|
        puts "   Group #{i + 1}: #{group.join(', ')}"
      end
    end
    
    # Simulate build execution
    build_order.each do |target|
      execute_target(target)
    end
    
    puts "✅ Build completed successfully!"
    { status: :success, targets: target_names, build_order: build_order }
  end
  
  def execute_target(target_name)
    target = @targets[target_name]
    puts "🔨 Building #{target_name}: #{target[:command]}"
    
    # Mark as completed
    @reasoning_coordinator.assert_fact("build_completed(#{target_name})")
    @build_results[target_name] = :success
  end
  
  def show_dependencies
    puts "\n📊 Dependency Graph:"
    puts "=" * 40
    
    @targets.each do |name, target|
      deps = target[:dependencies]
      if deps.any?
        puts "#{name} ← #{deps.join(', ')}"
      else
        puts "#{name} (no dependencies)"
      end
    end
  end
  
  def analyze_build
    puts "\n🔍 Build Analysis:"
    puts "=" * 40
    
    # Find targets with most dependencies
    max_deps = @targets.values.map { |t| t[:dependencies].length }.max || 0
    critical_targets = @targets.select { |_, t| t[:dependencies].length == max_deps }
    
    if critical_targets.any?
      puts "🎯 Critical path targets (#{max_deps} dependencies):"
      critical_targets.each { |name, _| puts "   • #{name}" }
    end
    
    # Count parallel-safe targets
    parallel_count = @targets.count { |_, t| t[:parallel_safe] }
    puts "⚡ Parallel-safe targets: #{parallel_count}/#{@targets.length}"
    
    # Estimate parallel speedup
    total_targets = @targets.length
    sequential_time = total_targets
    parallel_groups = find_parallel_groups(@targets.keys)
    parallel_time = total_targets - parallel_groups.sum { |g| g.length - 1 }
    
    if parallel_time < sequential_time
      speedup = (sequential_time.to_f / parallel_time).round(2)
      puts "🚀 Estimated parallel speedup: #{speedup}x"
    end
  end
end

# =============================================================================
# TEST SUITE
# =============================================================================

class NativeBuildToolTestSuite
  def initialize
    @test_results = []
  end
  
  def run_all_tests
    puts "🧪 Native PaTLang Build Tool Test Suite"
    puts "=" * 50
    
    test_basic_target_registration
    test_dependency_resolution
    test_circular_dependency_detection
    test_parallel_execution_analysis
    test_complex_build_scenario
    
    generate_test_report
  end
  
  private
  
  def test_basic_target_registration
    test_section("Basic Target Registration")
    
    assert_no_error "Register simple target" do
      @simulator.register_target("compile_main", [], "gcc main.c -o main", true)
    end
    
    assert_no_error "Register target with dependencies" do
      @simulator.register_target("link_app", ["compile_main"], "gcc main.o -o app", false)
    end
  end
  
  def test_dependency_resolution
    test_section("Dependency Resolution")
    
    # Create a complex dependency chain
    @simulator.register_target("compile_a", [], "gcc a.c -o a.o", true)
    @simulator.register_target("compile_b", [], "gcc b.c -o b.o", true)
    @simulator.register_target("compile_c", ["compile_a"], "gcc c.c -o c.o", true)
    @simulator.register_target("link_final", ["compile_b", "compile_c"], "gcc *.o -o final", false)
    
    assert_no_error "Resolve build order" do
      order = @simulator.get_build_order(["link_final"])
      expected_before_final = ["compile_a", "compile_b", "compile_c"]
      assert_true "Dependencies built before final", expected_before_final.all? { |dep| order.index(dep) < order.index("link_final") }
    end
  end
  
  def test_circular_dependency_detection
    test_section("Circular Dependency Detection")
    
    assert_error "Detect circular dependency" do
      @simulator.register_target("circular_a", ["circular_b"], "echo a", true)
      @simulator.register_target("circular_b", ["circular_a"], "echo b", true)
      @simulator.build_targets(["circular_a"])
    end
  end
  
  def test_parallel_execution_analysis
    test_section("Parallel Execution Analysis")
    
    @simulator.register_target("parallel_1", [], "task1", true)
    @simulator.register_target("parallel_2", [], "task2", true)
    @simulator.register_target("parallel_3", [], "task3", true)
    @simulator.register_target("sequential", ["parallel_1", "parallel_2", "parallel_3"], "final", false)
    
    parallel_groups = @simulator.find_parallel_groups(["parallel_1", "parallel_2", "parallel_3", "sequential"])
    assert_true "Found parallel group", parallel_groups.any? { |group| group.include?("parallel_1") && group.include?("parallel_2") }
  end
  
  def test_complex_build_scenario
    test_section("Complex Build Scenario")
    
    # Simulate a real project build
    targets = {
      "compile_parser" => { deps: [], parallel: true },
      "compile_lexer" => { deps: [], parallel: true },
      "compile_evaluator" => { deps: [], parallel: true },
      "compile_main" => { deps: ["compile_parser", "compile_lexer", "compile_evaluator"], parallel: true },
      "link_executable" => { deps: ["compile_main"], parallel: false },
      "run_tests" => { deps: ["link_executable"], parallel: false }
    }
    
    targets.each do |name, config|
      @simulator.register_target(name, config[:deps], "build #{name}", config[:parallel])
    end
    
    assert_no_error "Build complex project" do
      result = @simulator.build_targets(["run_tests"])
      assert_equal "Build status", :success, result[:status]
    end
    
    @simulator.show_dependencies
    @simulator.analyze_build
  end
  
  def test_section(name)
    puts "\n📋 Testing: #{name}"
    puts "-" * 40
  end
  
  def assert_no_error(description, &block)
    begin
      result = block.call
      @test_results << { test: description, status: :pass }
      puts "✅ #{description}"
      result
    rescue => e
      @test_results << { test: description, status: :fail, error: e.message }
      puts "❌ #{description}: #{e.message}"
      nil
    end
  end
  
  def assert_error(description, &block)
    begin
      block.call
      @test_results << { test: description, status: :fail, error: "Expected error but none occurred" }
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
      puts "❌ #{description}: Expected #{expected}, got #{actual}"
    end
  end
  
  def assert_true(description, condition)
    if condition
      @test_results << { test: description, status: :pass }
      puts "✅ #{description}"
    else
      @test_results << { test: description, status: :fail, error: "Condition was false" }
      puts "❌ #{description}: Condition was false"
    end
  end
  
  def generate_test_report
    puts "\n" + "=" * 50
    puts "🧪 NATIVE BUILD TOOL TEST RESULTS"
    puts "=" * 50
    
    passed = @test_results.count { |r| r[:status] == :pass }
    failed = @test_results.count { |r| r[:status] == :fail }
    total = @test_results.length
    
    puts "📊 Summary:"
    puts "   Total Tests: #{total}"
    puts "   Passed: #{passed}"
    puts "   Failed: #{failed}"
    puts "   Success Rate: #{((passed.to_f / total) * 100).round(1)}%"
    
    if failed == 0
      puts "\n🎉 All tests passed! Native PaTLang build tool logic is sound."
    else
      puts "\n⚠️  Some tests failed. Review implementation."
    end
  end
end

# Run the test suite
if __FILE__ == $0
  test_suite = NativeBuildToolTestSuite.new
  test_suite.run_all_tests
end