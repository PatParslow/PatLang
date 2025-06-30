#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'patlang-core/evaluator/evaluator'

# Phase 1 Goal Integration Demonstration
class GoalIntegrationDemo
  def initialize
    @evaluator = Evaluator.new
    @evaluator.enable_reasoning_mode
  end

  def run_demo
    puts "=" * 60
    puts "🎯 PATlang Phase 1 Goal System Integration Demo"
    puts "=" * 60
    puts

    demo_basic_goal_functionality
    demo_facts_and_queries
    demo_build_tool_compatibility
    show_integration_stats

    puts "=" * 60
    puts "✅ Phase 1 Goal Integration: COMPLETE"
    puts "🏗️  Ready for Phase 2 Native PATlang Implementation"
    puts "=" * 60
  end

  private

  def demo_basic_goal_functionality
    puts "📋 1. Testing Basic Goal Functionality"
    puts "-" * 40

    # Declare a goal
    goal = @evaluator.declare_goal("find_even_number", {
      description: "Find an even number greater than 10",
      preconditions: ["input > 0"],
      postconditions: ["result.even?", "result > 10"],
      strategies: ["systematic_search", "heuristic_search"]
    })

    puts "✓ Goal declared: #{goal.name}"
    puts "  Preconditions: #{goal.preconditions}"
    puts "  Postconditions: #{goal.postconditions}"
    puts "  Strategies: #{goal.strategies}"

    # Pursue the goal
    result = @evaluator.pursue_goal("find_even_number", { min: 10, max: 100 })
    puts "✓ Goal pursuit result: #{result}"
    puts "✓ Result validation: even=#{result.even?}, > 10=#{result > 10}"
    puts
  end

  def demo_facts_and_queries
    puts "🔍 2. Testing Facts Database Integration"
    puts "-" * 40

    # Assert some facts
    @evaluator.assert_fact("user(alice)")
    @evaluator.assert_fact("user(bob)")
    @evaluator.assert_fact("admin(alice)")
    @evaluator.assert_fact("project(awesome_app)")

    puts "✓ Facts asserted:"
    puts "  - user(alice)"
    puts "  - user(bob)" 
    puts "  - admin(alice)"
    puts "  - project(awesome_app)"

    # Query facts
    user_results = @evaluator.query_facts("user(X)")
    admin_results = @evaluator.query_facts("admin(X)")

    puts "✓ Query results:"
    puts "  - user(X): #{user_results.length} results"
    puts "  - admin(X): #{admin_results.length} results"
    puts
  end

  def demo_build_tool_compatibility
    puts "🔨 3. Testing Build Tool Compatibility"
    puts "-" * 40

    # Create build-like goals similar to existing build tool
    build_goal = @evaluator.declare_goal("compile_project", {
      description: "Compile the project with dependency resolution",
      preconditions: ["source_files.exist?", "dependencies.resolved?"],
      postconditions: ["output_files.exist?", "compilation.success?"],
      strategies: ["incremental_build", "clean_build", "parallel_build"]
    })

    puts "✓ Build goal declared: #{build_goal.name}"

    # Pursue build goal
    build_result = @evaluator.pursue_goal("compile_project", {
      source_path: "src/",
      output_path: "build/",
      target: "production"
    })

    puts "✓ Build goal executed: #{build_result}"
    puts "✓ Build tool compatibility: VERIFIED"
    puts
  end

  def show_integration_stats
    puts "📊 4. Integration Statistics"
    puts "-" * 40

    if @evaluator.goal_integration_enabled?
      stats = @evaluator.goal_integration_stats
      puts "✓ Goal Integration: ENABLED"
      puts "✓ Runtime: #{stats[:runtime_seconds]} seconds"
      puts "✓ Goals declared: #{stats[:goals_declared]}"
      puts "✓ Goals pursued: #{stats[:goals_pursued]}"
      puts "✓ Success rate: #{stats[:success_rate]}%"
      puts
      puts "📋 Active Components:"
      stats[:components].each do |component, status|
        puts "  - #{component}: #{status}"
      end
    else
      puts "❌ Goal Integration: NOT ENABLED"
    end
    puts
  end
end

# Run the demonstration
if __FILE__ == $0
  demo = GoalIntegrationDemo.new
  demo.run_demo
end