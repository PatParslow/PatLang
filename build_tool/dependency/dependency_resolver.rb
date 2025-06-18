# frozen_string_literal: true

require_relative '../../src/reasoning/facts_database'
require_relative '../../src/reasoning/reasoning_coordinator'

# DependencyResolver uses PaTLang's reasoning system to perform
# sophisticated dependency analysis, resolution, and optimization
# for build target execution planning.
class DependencyResolver
  attr_reader :reasoning_coordinator, :facts_db, :dependency_graph

  def initialize(reasoning_coordinator = nil)
    @reasoning_coordinator = reasoning_coordinator || ReasoningCoordinator.new
    @facts_db = FactsDatabase.new
    @dependency_graph = {}
    @resolution_cache = {}
    @circular_dependencies = []
    
    setup_dependency_reasoning
  end

  def add_target_dependencies(target, dependencies)
    @dependency_graph[target.to_sym] = dependencies.map(&:to_sym)
    
    # Assert dependency facts for reasoning
    dependencies.each do |dep|
      fact = "depends_on(#{target}, #{dep})"
      @facts_db.assert_fact(fact)
      @reasoning_coordinator.assert_fact(fact) if @reasoning_coordinator.reasoning_mode_enabled?
    end
  end

  def resolve_dependencies(targets)
    targets = Array(targets).map(&:to_sym)
    
    # Check cache first
    cache_key = targets.sort.join(',')
    return @resolution_cache[cache_key] if @resolution_cache.key?(cache_key)
    
    # Perform topological sort with cycle detection
    resolution_result = perform_topological_sort(targets)
    
    # Cache the result
    @resolution_cache[cache_key] = resolution_result
    
    resolution_result
  end

  def detect_circular_dependencies
    visited = Set.new
    rec_stack = Set.new
    cycles = []
    
    @dependency_graph.each_key do |target|
      next if visited.include?(target)
      
      cycle = detect_cycle_dfs(target, visited, rec_stack, [])
      cycles << cycle if cycle
    end
    
    @circular_dependencies = cycles
    cycles
  end

  def analyze_dependency_impact(target)
    target = target.to_sym
    
    # Find all targets that depend on this target (forward dependencies)
    forward_deps = find_forward_dependencies(target)
    
    # Find all targets this target depends on (backward dependencies)  
    backward_deps = find_backward_dependencies(target)
    
    # Calculate impact metrics
    {
      target: target,
      forward_dependencies: forward_deps,
      backward_dependencies: backward_deps,
      impact_score: calculate_impact_score(forward_deps, backward_deps),
      critical_path: is_on_critical_path?(target),
      parallel_opportunities: find_parallel_opportunities(target)
    }
  end

  def optimize_build_order(targets)
    # Use reasoning system to find optimal build order
    base_order = resolve_dependencies(targets)
    return base_order if base_order[:status] != :success
    
    # Apply optimization strategies
    optimized_order = apply_optimization_strategies(base_order[:order])
    
    {
      status: :success,
      original_order: base_order[:order],
      optimized_order: optimized_order,
      optimization_applied: optimized_order != base_order[:order],
      parallel_groups: identify_parallel_groups(optimized_order)
    }
  end

  def create_execution_plan(targets, options = {})
    resolution = resolve_dependencies(targets)
    return resolution if resolution[:status] != :success
    
    optimization = optimize_build_order(targets)
    
    {
      status: :success,
      targets: targets,
      execution_order: optimization[:optimized_order],
      parallel_groups: optimization[:parallel_groups],
      dependency_analysis: analyze_all_dependencies(targets),
      estimated_duration: estimate_build_duration(optimization[:optimized_order]),
      resource_requirements: estimate_resource_requirements(targets),
      optimization_metrics: {
        original_steps: resolution[:order].length,
        optimized_steps: optimization[:optimized_order].length,
        parallel_opportunities: optimization[:parallel_groups].count { |g| g.length > 1 }
      }
    }
  end

  def query_dependencies(query_string)
    # Use reasoning system to query dependency relationships
    return [] unless @reasoning_coordinator.reasoning_mode_enabled?
    
    @reasoning_coordinator.query(query_string)
  end

  def get_dependency_facts
    @facts_db.get_facts
  end

  def clear_cache
    @resolution_cache.clear
  end

  private

  def setup_dependency_reasoning
    # Set up reasoning rules for dependency analysis
    if @reasoning_coordinator.reasoning_mode_enabled?
      # Rule: transitive dependencies
      @reasoning_coordinator.define_rule("depends_on(X, Z) :- depends_on(X, Y), depends_on(Y, Z)")
      
      # Rule: circular dependency detection
      @reasoning_coordinator.define_rule("circular_dep(X) :- depends_on(X, X)")
      @reasoning_coordinator.define_rule("circular_dep(X) :- depends_on(X, Y), depends_on(Y, X)")
    end
  end

  def perform_topological_sort(targets)
    # Kahn's algorithm for topological sorting
    in_degree = calculate_in_degrees(targets)
    queue = targets.select { |t| in_degree[t] == 0 }
    result = []
    
    while queue.any?
      current = queue.shift
      result << current
      
      # Process dependencies
      (@dependency_graph[current] || []).each do |dep|
        in_degree[dep] -= 1
        if in_degree[dep] == 0
          queue << dep
        end
      end
    end
    
    # Check for cycles
    if result.length != targets.length
      cycles = detect_circular_dependencies
      return {
        status: :circular_dependency,
        error: "Circular dependencies detected",
        cycles: cycles,
        partial_order: result
      }
    end
    
    {
      status: :success,
      order: result.reverse, # Reverse for correct build order
      analysis: {
        total_targets: targets.length,
        dependency_edges: count_dependency_edges(targets),
        max_depth: calculate_max_dependency_depth(result)
      }
    }
  end

  def calculate_in_degrees(targets)
    in_degree = {}
    targets.each { |t| in_degree[t] = 0 }
    
    targets.each do |target|
      (@dependency_graph[target] || []).each do |dep|
        in_degree[dep] = (in_degree[dep] || 0) + 1
      end
    end
    
    in_degree
  end

  def detect_cycle_dfs(target, visited, rec_stack, path)
    visited.add(target)
    rec_stack.add(target)
    path << target
    
    (@dependency_graph[target] || []).each do |dep|
      if !visited.include?(dep)
        cycle = detect_cycle_dfs(dep, visited, rec_stack, path.dup)
        return cycle if cycle
      elsif rec_stack.include?(dep)
        # Found cycle
        cycle_start = path.index(dep)
        return path[cycle_start..-1] + [dep] if cycle_start
      end
    end
    
    rec_stack.delete(target)
    nil
  end

  def find_forward_dependencies(target)
    forward_deps = []
    
    @dependency_graph.each do |t, deps|
      forward_deps << t if deps.include?(target)
    end
    
    forward_deps
  end

  def find_backward_dependencies(target)
    all_deps = Set.new
    to_visit = [@dependency_graph[target] || []].flatten
    
    while to_visit.any?
      dep = to_visit.shift
      next if all_deps.include?(dep)
      
      all_deps.add(dep)
      to_visit.concat(@dependency_graph[dep] || [])
    end
    
    all_deps.to_a
  end

  def calculate_impact_score(forward_deps, backward_deps)
    # Simple impact scoring based on dependency count
    forward_weight = forward_deps.length * 2 # Forward deps have higher impact
    backward_weight = backward_deps.length
    
    forward_weight + backward_weight
  end

  def is_on_critical_path?(target)
    # Simplified critical path detection
    forward_deps = find_forward_dependencies(target)
    backward_deps = find_backward_dependencies(target)
    
    # High impact targets are likely on critical path
    (forward_deps.length + backward_deps.length) > 2
  end

  def find_parallel_opportunities(target)
    # Find targets that can be built in parallel with this target
    target_deps = @dependency_graph[target] || []
    
    parallel_candidates = []
    @dependency_graph.each do |other_target, other_deps|
      next if other_target == target
      
      # Can be parallel if no dependency relationship exists
      if !target_deps.include?(other_target) && !other_deps.include?(target)
        parallel_candidates << other_target
      end
    end
    
    parallel_candidates
  end

  def apply_optimization_strategies(order)
    # Apply various optimization strategies
    optimized = order.dup
    
    # Strategy 1: Group independent targets
    optimized = group_independent_targets(optimized)
    
    # Strategy 2: Minimize context switches
    optimized = minimize_context_switches(optimized)
    
    optimized
  end

  def group_independent_targets(order)
    # Group targets that have no dependencies between them
    groups = []
    remaining = order.dup
    
    while remaining.any?
      current_group = []
      i = 0
      
      while i < remaining.length
        target = remaining[i]
        target_deps = @dependency_graph[target] || []
        
        # Check if target can be added to current group
        can_add = current_group.none? do |group_target|
          target_deps.include?(group_target) || 
          (@dependency_graph[group_target] || []).include?(target)
        end
        
        if can_add
          current_group << target
          remaining.delete_at(i)
        else
          i += 1
        end
      end
      
      groups << current_group if current_group.any?
      break if current_group.empty? # Safety check
    end
    
    groups.flatten
  end

  def minimize_context_switches(order)
    # Simple heuristic: group targets by type if available
    # This would require target type information
    order # Return as-is for now
  end

  def identify_parallel_groups(order)
    # Group consecutive targets that can run in parallel
    groups = []
    current_group = []
    
    order.each do |target|
      if current_group.empty?
        current_group << target
      else
        # Check if target can be parallel with current group
        can_parallel = current_group.all? do |group_target|
          target_deps = @dependency_graph[target] || []
          group_deps = @dependency_graph[group_target] || []
          
          !target_deps.include?(group_target) && !group_deps.include?(target)
        end
        
        if can_parallel
          current_group << target
        else
          groups << current_group
          current_group = [target]
        end
      end
    end
    
    groups << current_group if current_group.any?
    groups
  end

  def analyze_all_dependencies(targets)
    analysis = {}
    
    targets.each do |target|
      analysis[target] = analyze_dependency_impact(target)
    end
    
    analysis
  end

  def estimate_build_duration(order)
    # Simple estimation based on number of targets
    # In real implementation, would use historical data
    base_time = order.length * 10 # 10 seconds per target
    
    {
      estimated_seconds: base_time,
      estimated_minutes: (base_time / 60.0).round(1),
      confidence: :low # Would be higher with historical data
    }
  end

  def estimate_resource_requirements(targets)
    # Simple resource estimation
    {
      max_parallel_jobs: [targets.length, 4].min,
      memory_estimate_mb: targets.length * 256,
      disk_space_estimate_mb: targets.length * 100,
      network_required: false
    }
  end

  def count_dependency_edges(targets)
    edges = 0
    targets.each do |target|
      edges += (@dependency_graph[target] || []).length
    end
    edges
  end

  def calculate_max_dependency_depth(order)
    max_depth = 0
    
    order.each do |target|
      depth = calculate_target_depth(target, Set.new)
      max_depth = [max_depth, depth].max
    end
    
    max_depth
  end

  def calculate_target_depth(target, visited)
    return 0 if visited.include?(target)
    
    visited.add(target)
    deps = @dependency_graph[target] || []
    
    return 0 if deps.empty?
    
    max_dep_depth = deps.map { |dep| calculate_target_depth(dep, visited.dup) }.max
    1 + max_dep_depth
  end
end