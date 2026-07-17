# frozen_string_literal: true

require_relative '../../patlang-core/reasoning/reasoning_coordinator'
require_relative '../../patlang-core/reasoning/advanced_goal_strategies'
require_relative 'build_goal'
require_relative 'build_context'

# BuildRunner orchestrates build execution using PaTLang's goal-oriented
# and reasoning systems for intelligent dependency resolution, parallel execution,
# and adaptive build strategies.
class BuildRunner
  attr_reader :reasoning_coordinator, :goal_strategies, :build_targets, :context

  def initialize(evaluator = nil)
    @reasoning_coordinator = ReasoningCoordinator.new(evaluator)
    @goal_strategies = AdvancedGoalStrategies.new(evaluator)
    @build_targets = {}
    @context = nil
    @execution_history = []
    @parallel_execution_enabled = true
    
    # Enable reasoning mode for build operations
    @reasoning_coordinator.enable_reasoning_mode
    
    setup_build_reasoning
    setup_event_handlers
  end

  def define_target(name, **options, &block)
    # Create build goal with block resolution if provided
    if block_given?
      options[:block] = block
    end
    
    target = BuildGoal.new(name, **options)
    @build_targets[name.to_sym] = target
    
    # Register with reasoning coordinator for dependency resolution
    @reasoning_coordinator.create_goal(name, **target.to_build_info)
    
    target
  end

  def build(targets = nil, **build_options)
    targets ||= @build_targets.keys
    targets = Array(targets).map(&:to_sym)
    
    # Initialize build context
    @context = BuildContext.new(build_options)
    
    # Ensure reasoning mode is enabled for intelligent build coordination
    @reasoning_coordinator.enable_reasoning_mode unless @reasoning_coordinator.reasoning_mode_enabled?
    
    begin
      # Create build execution plan using dependency resolution
      execution_plan = create_build_execution_plan(targets)
      
      # Execute build plan with appropriate strategy
      execution_results = execute_build_plan(execution_plan)
      
      # Analyze and report results
      build_summary = analyze_build_results(execution_results)
      
      {
        status: build_summary[:overall_status],
        targets_built: execution_results.keys,
        build_time: @context.build_elapsed_time,
        results: execution_results,
        summary: build_summary
      }
      
    rescue => e
      # Re-raise circular dependency errors and missing dependency errors
      if e.message.include?("Circular dependency") || e.message.include?("Missing dependency") || e.message.include?("nonexistent")
        raise e
      end
      
      {
        status: :error,
        error: e.message,
        backtrace: e.backtrace.first(5),
        build_time: @context.build_elapsed_time
      }
    ensure
      @reasoning_coordinator.disable_reasoning_mode
    end
  end

  def clean(targets = nil)
    targets ||= @build_targets.keys
    targets = Array(targets).map(&:to_sym)
    
    cleaned = []
    targets.each do |target_name|
      target = @build_targets[target_name]
      next unless target
      
      # Remove output files
      target.outputs.each do |output|
        if File.exist?(output)
          File.delete(output)
          cleaned << output
        end
      end
    end
    
    { cleaned_files: cleaned, count: cleaned.length }
  end

  def list_targets
    @build_targets.map do |name, target|
      {
        name: name,
        type: target.target_type,
        inputs: target.inputs,
        outputs: target.outputs,
        dependencies: target.dependencies,
        up_to_date: !target.needs_rebuild?(@context || BuildContext.new)
      }
    end
  end

  def dependency_graph
    graph = {}
    @build_targets.each do |name, target|
      graph[name] = target.dependencies.map(&:to_sym)
    end
    graph
  end

  private

  def setup_build_reasoning
    # Configure reasoning coordinator for build-specific logic
    @reasoning_coordinator.on_event(:goal_pursuit_started) do |event|
      puts "Building target: #{event[:goal_name]}" if @context&.get(:verbose)
    end
    
    @reasoning_coordinator.on_event(:goal_pursuit_failed) do |event|
      puts "Build failed for #{event[:goal_name]}: #{event[:error]}"
    end
  end

  def setup_event_handlers
    # Set up goal strategy event handlers for build monitoring
    @goal_strategies.on_event(:strategy_executed) do |event|
      @execution_history << {
        target: event[:goal],
        strategy: event[:strategy],
        timestamp: event[:timestamp]
      }
    end
  end

  def create_build_execution_plan(targets)
    # Use reasoning system to resolve dependencies and create execution plan
    dependency_facts = assert_dependency_facts
    execution_order = resolve_build_dependencies(targets)
    
    {
      targets: targets,
      execution_order: execution_order,
      parallel_groups: identify_parallel_groups(execution_order),
      dependency_facts: dependency_facts
    }
  end

  def assert_dependency_facts
    # Assert dependency relationships as facts for reasoning
    facts = []
    @build_targets.each do |name, target|
      target.dependencies.each do |dep|
        fact = "depends_on(#{name}, #{dep})"
        @reasoning_coordinator.assert_fact(fact)
        facts << fact
      end
      
      # Assert target properties
      @reasoning_coordinator.assert_fact("target_type(#{name}, #{target.target_type})")
      @reasoning_coordinator.assert_fact("parallel_safe(#{name})") if target.parallel_safe
    end
    facts
  end

  def resolve_build_dependencies(targets)
    # Topological sort of dependencies
    resolved = []
    temp_mark = Set.new
    perm_mark = Set.new
    
    visit = lambda do |target|
      return if perm_mark.include?(target)
      
      if temp_mark.include?(target)
        raise "Circular dependency detected involving #{target}"
      end
      
      temp_mark.add(target)
      
      build_target = @build_targets[target]
      if build_target
        build_target.dependencies.each do |dep|
          dep_sym = dep.to_sym
          unless @build_targets.key?(dep_sym)
            raise "Missing dependency: #{dep} required by #{target}"
          end
          visit.call(dep_sym)
        end
      end
      
      temp_mark.delete(target)
      perm_mark.add(target)
      resolved << target
    end
    
    targets.each { |target| visit.call(target) }
    resolved
  end

  def identify_parallel_groups(execution_order)
    # Group targets that can be built in parallel
    groups = []
    remaining = execution_order.dup
    
    while remaining.any?
      parallel_group = []
      
      remaining.each do |target|
        target_obj = @build_targets[target]
        next unless target_obj
        
        # Check if all dependencies are already completed
        deps_satisfied = target_obj.dependencies.all? do |dep|
          !remaining.include?(dep.to_sym)
        end
        
        if deps_satisfied && (target_obj.parallel_safe || parallel_group.empty?)
          parallel_group << target
        end
      end
      
      # Remove targets in this group from remaining
      parallel_group.each { |target| remaining.delete(target) }
      groups << parallel_group if parallel_group.any?
      
      # Safety check to prevent infinite loops
      break if parallel_group.empty? && remaining.any?
    end
    
    groups
  end

  def execute_build_plan(execution_plan)
    results = {}
    
    if @parallel_execution_enabled && execution_plan[:parallel_groups].length > 1
      # Execute using parallel strategy
      results = execute_parallel_build(execution_plan)
    else
      # Execute sequentially
      results = execute_sequential_build(execution_plan)
    end
    
    results
  end

  def execute_parallel_build(execution_plan)
    results = {}
    
    execution_plan[:parallel_groups].each do |group|
      if group.length > 1
        # Execute group in parallel using goal strategies
        parallel_results = execute_parallel_group(group)
        results.merge!(parallel_results)
      else
        # Single target in group
        target = group.first
        results[target] = execute_single_target(target)
      end
    end
    
    results
  end

  def execute_sequential_build(execution_plan)
    results = {}
    
    execution_plan[:execution_order].each do |target|
      results[target] = execute_single_target(target)
      
      # Stop on first failure unless continuing on error
      if results[target][:status] == :failure && !@context.get(:continue_on_error)
        break
      end
    end
    
    results
  end

  def execute_parallel_group(group)
    # Use advanced goal strategies for parallel execution
    parallel_definition = create_parallel_strategy_definition(group)
    
    strategy_result = @goal_strategies.execute_parallel_strategies(
      "parallel_build_#{group.join('_')}", 
      parallel_definition, 
      @context.to_h
    )
    
    # Convert strategy results to build results
    convert_strategy_results_to_build_results(group, strategy_result)
  end

  def execute_single_target(target_name)
    target = @build_targets[target_name]
    return { status: :not_found, error: "Target #{target_name} not found" } unless target
    
    # Update context with dependency info
    update_dependency_context(target)
    
    # Execute target using goal resolution
    begin
      result = @reasoning_coordinator.pursue_goal(target_name, **@context.to_h)
      
      # Update dependency tracking
      @context.set_dependency_info(target_name, {
        last_built: Time.now,
        result: result,
        build_successful: result[:status] != :failure
      })
      
      result
    rescue => e
      {
        status: :failure,
        target: target_name,
        error: e.message,
        timestamp: Time.now
      }
    end
  end

  def create_parallel_strategy_definition(group)
    strategies = group.map.with_index do |target, index|
      {
        name: "build_#{target}".to_sym,
        weight: 1.0 / group.length,
        expertise_domain: @build_targets[target]&.target_type || "generic"
      }
    end
    
    "parallel_strategies: #{strategies.inspect}"
  end

  def convert_strategy_results_to_build_results(group, strategy_result)
    results = {}
    
    group.each_with_index do |target, index|
      contribution = strategy_result[:strategy_contributions][index]
      
      results[target] = if contribution && contribution[:performance] > 0.7
        {
          status: :success,
          target: target,
          performance: contribution[:performance],
          strategy: contribution[:strategy],
          timestamp: Time.now
        }
      else
        {
          status: :failure,
          target: target,
          error: "Parallel execution failed",
          timestamp: Time.now
        }
      end
    end
    
    results
  end

  def update_dependency_context(target)
    target.dependencies.each do |dep_name|
      dep_info = @context.get_dependency_info(dep_name.to_sym)
      if dep_info
        @context.set("#{dep_name}_result", dep_info[:result])
        @context.set("#{dep_name}_built_at", dep_info[:last_built])
      end
    end
  end

  def analyze_build_results(results)
    successful = results.values.count { |r| r[:status] == :success || r[:status] == :up_to_date }
    failed = results.values.count { |r| r[:status] == :failure }
    
    {
      overall_status: failed > 0 ? :partial_failure : :success,
      successful_targets: successful,
      failed_targets: failed,
      total_targets: results.length,
      build_time: @context.build_elapsed_time,
      parallel_groups_used: results.values.any? { |r| r.key?(:strategy) }
    }
  end
end