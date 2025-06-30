# Time-Travel Debugging with Message History

## Overview

Patlang's time-travel debugging system leverages message persistence to enable developers to step through program execution history, analyze state changes, and understand complex system behavior. This revolutionary debugging approach transforms how developers investigate issues and understand program flow.

## Table of Contents

1. [Debug Session Management](#debug-session-management)
2. [Stepping Through Time](#stepping-through-time)
3. [Breakpoints and Conditions](#breakpoints-and-conditions)
4. [State Inspection](#state-inspection)
5. [Flow Analysis](#flow-analysis)
6. [Real-World Debugging Scenarios](#real-world-debugging-scenarios)

## Debug Session Management

### Starting a Debug Session

```patlang
# Create a time-travel debugging session
make a template called TimeravelDebugger {
  TimeravelDebugger has:
    session_id - text
    message_history - list of PatlangMessage
    state_snapshots - list of StateSnapshot
    current_time_index - number
    breakpoints - list of DebugBreakpoint
    watch_expressions - list of WatchExpression
    
  # Start debugging session for a time range
  start_session takes:
    start_time - time
    end_time - time
    focus_areas - DebugFocusAreas = DebugFocusAreas.all
    
  start_session returns: {
    session_id = generate_debug_session_id()
    
    # Load message history for the time range
    message_history = message_persistence.get_messages_between(
      start_time, 
      end_time,
      filter: create_debug_filter(focus_areas)
    )
    
    # Load state snapshots
    state_snapshots = state_persistence.get_snapshots_between(start_time, end_time)
    
    current_time_index = 0
    
    emit debug_session: started with {
      session_id: session_id,
      message_count: message_history.length,
      snapshot_count: state_snapshots.length,
      time_range: { start: start_time, end: end_time }
    }
    
    log("Debug session #{session_id} started with #{message_history.length} messages")
  }
}

# Start debugging yesterday's payment issue
debugger = TimeravelDebugger.new()

issue_start = Time.parse("2024-01-15 14:30:00")
issue_end = Time.parse("2024-01-15 15:00:00")

debugger.start_session(issue_start, issue_end, DebugFocusAreas.new(
  include_threads: ["payment_processor", "order_manager"],
  include_message_types: ["payment:*", "order:*", "error:*"],
  include_functions: ["process_payment", "validate_order"]
))
```

### Session Configuration

```patlang
# Configure debugging session behavior
configure debug_session {
  # Performance settings
  max_messages_in_memory: 100000
  lazy_load_large_sessions: true
  cache_state_snapshots: true
  
  # Analysis settings
  auto_detect_patterns: true
  track_variable_changes: true
  monitor_performance_metrics: true
  
  # Visualization settings
  generate_flow_diagrams: true
  create_timeline_visualization: true
  highlight_critical_paths: true
  
  # Export settings
  export_formats: ["json", "csv", "html_report"]
  include_source_context: true
}

# Create focused debugging sessions
make a function called create_focused_debug_session {
  create_focused_debug_session takes:
    incident_id - text
    focus_type - DebugFocusType
    
  create_focused_debug_session returns: {
    incident = incident_manager.get_incident(incident_id)
    
    case focus_type
    when DebugFocusType.error_analysis
      create_error_focused_session(incident)
    when DebugFocusType.performance_analysis
      create_performance_focused_session(incident)
    when DebugFocusType.state_corruption
      create_state_focused_session(incident)
    when DebugFocusType.concurrency_issues
      create_concurrency_focused_session(incident)
    end
  }
}
```

## Stepping Through Time

### Forward and Backward Navigation

```patlang
# Step forward in time
step_forward takes: steps - number = 1 returns: {
  for i in 1..steps do
    if current_time_index < message_history.length then
      current_message = message_history[current_time_index]
      
      # Check breakpoints
      if should_break_on_message(current_message) then
        emit debug_session: breakpoint_hit with {
          message_id: current_message.id,
          message_type: current_message.type,
          breakpoint_reason: get_breakpoint_reason(current_message),
          system_state: capture_current_debug_state()
        }
        break
      end
      
      # Apply message to debug state
      apply_message_to_debug_state(current_message)
      current_time_index = current_time_index + 1
      
      # Evaluate watch expressions
      evaluate_watch_expressions(current_message)
      
      # Update visualization
      update_debug_visualization(current_message)
      
      emit debug_session: stepped_forward with {
        current_message: current_message,
        time_index: current_time_index,
        timestamp: current_message.timestamp
      }
    else
      emit debug_session: end_of_history_reached
      break
    end
  end
}

# Step backward in time
step_backward takes: steps - number = 1 returns: {
  for i in 1..steps do
    if current_time_index > 0 then
      current_time_index = current_time_index - 1
      previous_message = message_history[current_time_index]
      
      # Reverse the effect of the message
      # This is complex and may require application-specific logic
      reverse_message_effect(previous_message)
      
      # Update watch expressions
      evaluate_watch_expressions_at_index(current_time_index)
      
      emit debug_session: stepped_backward with {
        reversed_message: previous_message,
        time_index: current_time_index,
        timestamp: previous_message.timestamp
      }
    else
      emit debug_session: beginning_of_history_reached
      break
    end
  end
}

# Jump to specific points in time
jump_to_message takes: message_id - text returns: {
  target_index = message_history.find_index { |msg| msg.id == message_id }
  
  if target_index >= 0 then
    jump_to_index(target_index)
  else
    throw MessageNotFoundError("Message #{message_id} not found in debug session")
  end
}

jump_to_time takes: target_time - time returns: {
  # Find closest message to target time
  target_index = message_history.find_index { |msg| msg.timestamp >= target_time }
  target_index = target_index || message_history.length - 1
  
  jump_to_index(target_index)
}

jump_to_index takes: target_index - number returns: {
  if target_index < current_time_index then
    # Going backward - need to restore from snapshot and replay
    closest_snapshot = find_closest_snapshot_before_index(target_index)
    restore_from_snapshot(closest_snapshot)
    
    # Replay messages from snapshot to target
    replay_messages_to_index(closest_snapshot.message_index, target_index)
  else
    # Going forward - just apply messages
    for i in current_time_index..target_index do
      apply_message_to_debug_state(message_history[i])
    end
  end
  
  current_time_index = target_index
  
  emit debug_session: jumped_to_index with {
    target_index: target_index,
    current_message: message_history[target_index],
    system_state: get_current_debug_state()
  }
}
```

### Smart Navigation

```patlang
# Navigate to next error or significant event
jump_to_next_error returns: {
  error_index = find_next_index_with_condition { |msg|
    msg.type.contains("error") or 
    msg.type.contains("failed") or 
    msg.type.contains("exception")
  }
  
  if error_index >= 0 then
    jump_to_index(error_index)
    
    emit debug_session: jumped_to_error with {
      error_message: message_history[error_index],
      error_context: get_error_context(error_index)
    }
  else
    emit debug_session: no_more_errors_found
  end
}

# Navigate to next state change for specific variable
jump_to_next_variable_change takes: variable_name - text returns: {
  change_index = find_next_index_with_condition { |msg|
    message_affects_variable(msg, variable_name)
  }
  
  if change_index >= 0 then
    jump_to_index(change_index)
    
    emit debug_session: jumped_to_variable_change with {
      variable_name: variable_name,
      change_message: message_history[change_index],
      old_value: get_variable_value_before_index(variable_name, change_index),
      new_value: get_variable_value_after_index(variable_name, change_index)
    }
  end
}

# Navigate to function entry/exit
jump_to_function_call takes: function_name - text returns: {
  call_index = find_next_index_with_condition { |msg|
    msg.type == "function:called" and msg.data.function_name == function_name
  }
  
  if call_index >= 0 then
    jump_to_index(call_index)
    
    # Also find the corresponding return
    return_index = find_function_return(function_name, call_index)
    
    emit debug_session: jumped_to_function_call with {
      function_name: function_name,
      call_index: call_index,
      return_index: return_index,
      execution_span: return_index - call_index
    }
  end
}
```

## Breakpoints and Conditions

### Conditional Breakpoints

```patlang
# Set sophisticated breakpoints
set_breakpoint takes:
  condition - BreakpointCondition
  action - BreakpointAction = BreakpointAction.pause
  
set_breakpoint returns: {
  breakpoint = DebugBreakpoint.new(condition, action)
  breakpoints.add(breakpoint)
  
  emit debug_session: breakpoint_set with {
    condition_description: condition.description,
    action: action.name,
    breakpoint_id: breakpoint.id
  }
}

# Message type breakpoints
debugger.set_breakpoint(
  condition: BreakpointCondition.message_type("payment:failed"),
  action: BreakpointAction.pause_and_capture_state
)

# Complex conditional breakpoints
debugger.set_breakpoint(
  condition: BreakpointCondition.and(
    BreakpointCondition.source_thread("payment_processor"),
    BreakpointCondition.data_contains("timeout"),
    BreakpointCondition.custom { |msg| msg.data.amount > 1000 }
  ),
  action: BreakpointAction.log_detailed_state
)

# Performance-based breakpoints
debugger.set_breakpoint(
  condition: BreakpointCondition.execution_time_exceeds(100),  # milliseconds
  action: BreakpointAction.capture_performance_profile
)

# State-based breakpoints
debugger.set_breakpoint(
  condition: BreakpointCondition.variable_value("user_count", ">", 1000),
  action: BreakpointAction.pause_and_analyze_memory
)

# Sequence-based breakpoints
debugger.set_breakpoint(
  condition: BreakpointCondition.message_sequence([
    "user:login_attempt",
    "auth:validation_failed", 
    "security:suspicious_activity"
  ]),
  action: BreakpointAction.trigger_security_analysis
)
```

### Breakpoint Actions

```patlang
# Define custom breakpoint actions
make a template called BreakpointAction {
  # Pause execution and wait for user input
  pause_and_capture_state = BreakpointAction.new("pause") { |context|
    state_snapshot = capture_detailed_state_snapshot(context)
    
    emit debug_session: execution_paused with {
      message: context.current_message,
      state_snapshot: state_snapshot,
      call_stack: context.call_stack,
      variable_states: context.variable_states
    }
    
    wait_for_user_continue()
  }
  
  # Log detailed information without pausing
  log_detailed_state = BreakpointAction.new("log_detailed") { |context|
    log("=== BREAKPOINT HIT ===")
    log("Message: #{context.current_message.type}")
    log("Timestamp: #{context.current_message.timestamp}")
    log("Source: #{context.current_message.source}")
    log("Data: #{context.current_message.data}")
    log("Variables: #{context.variable_states}")
    log("=====================")
  }
  
  # Capture performance profile
  capture_performance_profile = BreakpointAction.new("performance") { |context|
    performance_data = {
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      thread_states: get_all_thread_states(),
      message_queue_depths: get_queue_depths(),
      gc_stats: get_gc_statistics()
    }
    
    emit debug_session: performance_captured with performance_data
  }
  
  # Custom analysis action
  trigger_security_analysis = BreakpointAction.new("security") { |context|
    security_analyzer = SecurityAnalyzer.new()
    analysis_result = security_analyzer.analyze_context(context)
    
    emit security: debug_analysis with {
      analysis_result: analysis_result,
      threat_level: analysis_result.threat_level,
      recommendations: analysis_result.recommendations
    }
  }
}
```

## State Inspection

### Variable and Object Inspection

```patlang
# Add watch expressions for continuous monitoring
add_watch_expression takes:
  expression - text
  evaluation_context - WatchContext = WatchContext.current_state
  
add_watch_expression returns: {
  watch = WatchExpression.new(expression, evaluation_context)
  watch_expressions.add(watch)
  
  emit debug_session: watch_added with {
    expression: expression,
    context: evaluation_context.description,
    initial_value: evaluate_watch_expression(watch)
  }
}

# Example watch expressions
debugger.add_watch_expression("user_count")
debugger.add_watch_expression("payment_queue.depth")
debugger.add_watch_expression("error_rate_last_5_minutes")
debugger.add_watch_expression("memory_usage.percentage")
debugger.add_watch_expression("active_connections.count")

# Complex watch expressions
debugger.add_watch_expression("orders.filter { |o| o.status == 'pending' }.length")
debugger.add_watch_expression("calculate_average_response_time(last_100_requests)")

# Watch expression with conditions
debugger.add_watch_expression(
  expression: "payment_processor.connection_status",
  context: WatchContext.new(
    alert_on_change: true,
    alert_condition: { |old_val, new_val| new_val == "disconnected" }
  )
)
```

### Deep State Inspection

```patlang
# Get comprehensive state information
get_current_state returns: DebugState {
  DebugState.new(
    time_index: current_time_index,
    current_message: message_history[current_time_index],
    timestamp: message_history[current_time_index].timestamp,
    
    # System state
    variable_states: get_current_variable_states(),
    object_states: get_current_object_states(),
    thread_states: get_current_thread_states(),
    function_call_stack: get_current_call_stack(),
    
    # Message queue states
    queue_depths: get_all_queue_depths(),
    pending_messages: get_pending_messages(),
    
    # Performance metrics
    memory_usage: get_memory_usage_snapshot(),
    cpu_metrics: get_cpu_metrics_snapshot(),
    gc_statistics: get_gc_statistics(),
    
    # Watch expression values
    watch_values: evaluate_all_watch_expressions(),
    
    # Context information
    active_goals: get_active_goals(),
    event_subscriptions: get_active_event_subscriptions(),
    network_connections: get_network_connection_states()
  )
}

# Inspect specific objects at current time
inspect_object takes: object_id - text returns: ObjectInspection {
  current_state = get_current_state()
  object = current_state.object_states[object_id]
  
  if object.is_nil() then
    throw ObjectNotFoundError("Object #{object_id} not found at current time")
  end
  
  ObjectInspection.new(
    object_id: object_id,
    object_type: object.class.name,
    properties: object.properties,
    methods: object.methods,
    memory_usage: object.memory_usage,
    reference_count: object.reference_count,
    creation_time: object.creation_time,
    last_modified: object.last_modified,
    modification_history: get_object_modification_history(object_id)
  )
}

# Track object lifecycle
track_object_lifecycle takes: object_id - text returns: ObjectLifecycle {
  lifecycle_events = message_history.select { |msg|
    msg.data.affected_objects&.include?(object_id)
  }
  
  ObjectLifecycle.new(
    object_id: object_id,
    creation_event: find_object_creation_event(object_id),
    modification_events: find_object_modification_events(object_id),
    destruction_event: find_object_destruction_event(object_id),
    total_modifications: lifecycle_events.length,
    lifecycle_span: calculate_lifecycle_span(lifecycle_events)
  )
}
```

## Flow Analysis

### Message Flow Analysis

```patlang
# Analyze message flow patterns
analyze_message_flow takes:
  analysis_type - FlowAnalysisType
  
analyze_message_flow returns: {
  case analysis_type
  when FlowAnalysisType.thread_communication
    analyze_thread_communication_patterns()
  when FlowAnalysisType.error_propagation
    analyze_error_propagation_chains()
  when FlowAnalysisType.performance_bottlenecks
    analyze_performance_bottlenecks()
  when FlowAnalysisType.state_changes
    analyze_state_change_sequences()
  when FlowAnalysisType.data_flow
    analyze_data_flow_patterns()
  end
}

# Thread communication analysis
analyze_thread_communication_patterns returns: {
  thread_interactions = {}
  
  message_history.each do |message|
    source_thread = message.source.to_s
    target_thread = message.target.to_s
    
    thread_interactions[source_thread] ||= {}
    thread_interactions[source_thread][target_thread] ||= []
    thread_interactions[source_thread][target_thread].add({
      message_type: message.type,
      timestamp: message.timestamp,
      data_size: message.data.size
    })
  end
  
  # Generate communication flow analysis
  flow_analysis = thread_interactions.map do |source, targets|
    targets.map do |target, messages|
      {
        source: source,
        target: target,
        message_count: messages.length,
        message_types: messages.map(&:message_type).uniq,
        total_data: messages.sum(&:data_size),
        frequency: calculate_message_frequency(messages),
        patterns: detect_communication_patterns(messages)
      }
    end
  end.flatten
  
  emit debug_analysis: thread_communication_complete with {
    analysis: flow_analysis,
    visualization_data: generate_flow_diagram_data(flow_analysis)
  }
}

# Error propagation analysis
analyze_error_propagation_chains returns: {
  error_messages = message_history.select { |msg| 
    msg.type.contains("error") || msg.type.contains("failed") || msg.type.contains("exception")
  }
  
  error_chains = []
  
  error_messages.each do |error_message|
    # Trace back to find the root cause
    chain = trace_error_chain(error_message)
    
    if chain.length > 1 then
      error_chains.add({
        root_cause: chain.first,
        propagation_path: chain,
        affected_components: extract_affected_components(chain),
        impact_scope: calculate_impact_scope(chain),
        recovery_time: calculate_recovery_time(chain)
      })
    end
  end
  
  emit debug_analysis: error_propagation_complete with {
    error_chains: error_chains,
    root_causes: find_common_root_causes(error_chains),
    recommendations: generate_error_prevention_recommendations(error_chains)
  }
}
```

### Performance Analysis

```patlang
# Analyze performance bottlenecks
analyze_performance_bottlenecks returns: {
  performance_events = message_history.select { |msg|
    msg.processing_metadata&.execution_time > 0
  }
  
  # Group by function/operation type
  operation_performance = {}
  
  performance_events.each do |event|
    operation_type = extract_operation_type(event)
    execution_time = event.processing_metadata.execution_time
    
    operation_performance[operation_type] ||= []
    operation_performance[operation_type].add({
      timestamp: event.timestamp,
      execution_time: execution_time,
      message_id: event.id,
      context: event.data
    })
  end
  
  # Analyze each operation type
  bottleneck_analysis = operation_performance.map do |operation, events|
    sorted_times = events.map(&:execution_time).sort
    
    {
      operation: operation,
      total_calls: events.length,
      average_time: sorted_times.average,
      median_time: sorted_times.median,
      p95_time: sorted_times.percentile(95),
      p99_time: sorted_times.percentile(99),
      slowest_calls: events.sort_by(&:execution_time).last(5),
      trend_analysis: analyze_performance_trend(events),
      bottleneck_score: calculate_bottleneck_score(events)
    }
  end
  
  # Identify top bottlenecks
  top_bottlenecks = bottleneck_analysis.sort_by(&:bottleneck_score).reverse.first(10)
  
  emit debug_analysis: performance_bottlenecks_complete with {
    bottlenecks: top_bottlenecks,
    overall_performance: calculate_overall_performance_metrics(performance_events),
    optimization_recommendations: generate_optimization_recommendations(top_bottlenecks)
  }
}
```

## Real-World Debugging Scenarios

### Payment Processing Issue Investigation

```patlang
# Investigate payment timeout issues
investigate_payment_timeouts = TimeravelDebugger.new()

# Focus on payment-related activity during the incident
incident_time = Time.parse("2024-01-15 14:35:00")
investigation_window = 10.minutes

investigate_payment_timeouts.start_session(
  incident_time - investigation_window,
  incident_time + investigation_window,
  DebugFocusAreas.new(
    include_threads: ["payment_processor", "database_connection_pool", "external_gateway"],
    include_message_types: ["payment:*", "database:*", "network:*", "timeout:*"],
    include_performance_data: true
  )
)

# Set breakpoints for timeout scenarios
investigate_payment_timeouts.set_breakpoint(
  condition: BreakpointCondition.and(
    BreakpointCondition.message_type("payment:timeout"),
    BreakpointCondition.execution_time_exceeds(30000)  # 30 seconds
  ),
  action: BreakpointAction.capture_full_context
)

# Add watches for key metrics
investigate_payment_timeouts.add_watch_expression("payment_queue.depth")
investigate_payment_timeouts.add_watch_expression("database_connection_pool.active_connections")
investigate_payment_timeouts.add_watch_expression("external_gateway.response_time")
investigate_payment_timeouts.add_watch_expression("system_load.cpu_usage")

# Step through the incident
investigate_payment_timeouts.jump_to_time(incident_time - 5.minutes)
investigate_payment_timeouts.step_forward(50)  # Examine 50 messages leading up to incident

# Analyze patterns
timeout_analysis = investigate_payment_timeouts.analyze_message_flow(
  FlowAnalysisType.performance_bottlenecks
)

# Generate report
investigation_report = generate_investigation_report(
  debugger: investigate_payment_timeouts,
  analysis: timeout_analysis,
  focus: "payment_timeout_incident"
)
```

### Concurrency Bug Investigation

```patlang
# Investigate race condition causing data corruption
investigate_race_condition = TimeravelDebugger.new()

corruption_detected_time = Time.parse("2024-01-15 16:45:00")

investigate_race_condition.start_session(
  corruption_detected_time - 30.minutes,
  corruption_detected_time,
  DebugFocusAreas.new(
    include_threads: ["inventory_updater_1", "inventory_updater_2", "order_processor"],
    include_message_types: ["inventory:*", "order:*", "lock:*"],
    track_concurrent_access: true
  )
)

# Set breakpoints for concurrent access patterns
investigate_race_condition.set_breakpoint(
  condition: BreakpointCondition.concurrent_access_detected("inventory_item_123"),
  action: BreakpointAction.analyze_concurrency_scenario
)

# Watch for state inconsistencies
investigate_race_condition.add_watch_expression(
  expression: "inventory_item_123.stock_level",
  context: WatchContext.new(
    track_changes: true,
    alert_on_inconsistency: true
  )
)

# Step through the concurrent operations
investigate_race_condition.jump_to_first_concurrent_access("inventory_item_123")

# Analyze the race condition
concurrency_analysis = investigate_race_condition.analyze_message_flow(
  FlowAnalysisType.concurrency_conflicts
)

# Generate recommendations
race_condition_report = generate_concurrency_analysis_report(
  debugger: investigate_race_condition,
  analysis: concurrency_analysis,
  recommendations: [
    "Implement proper locking mechanism",
    "Use atomic operations for inventory updates", 
    "Add conflict detection and resolution"
  ]
)
```

### Memory Leak Investigation

```patlang
# Investigate gradual memory increase
investigate_memory_leak = TimeravelDebugger.new()

# Look at a longer time period for memory trends
leak_investigation_start = Time.parse("2024-01-15 00:00:00")
leak_investigation_end = Time.parse("2024-01-15 23:59:59")

investigate_memory_leak.start_session(
  leak_investigation_start,
  leak_investigation_end,
  DebugFocusAreas.new(
    include_memory_events: true,
    include_gc_events: true,
    include_object_lifecycle: true,
    sample_rate: "every_10_minutes"  # Don't load every message for long periods
  )
)

# Watch memory metrics
investigate_memory_leak.add_watch_expression("system_memory.heap_usage")
investigate_memory_leak.add_watch_expression("object_count_by_type")
investigate_memory_leak.add_watch_expression("gc_frequency")

# Set breakpoints for memory spikes
investigate_memory_leak.set_breakpoint(
  condition: BreakpointCondition.memory_usage_exceeds("500MB"),
  action: BreakpointAction.capture_memory_snapshot
)

# Jump through time in larger increments to see memory trend
for hour in 0..23 do
  time_point = leak_investigation_start + hour.hours
  investigate_memory_leak.jump_to_time(time_point)
  
  memory_snapshot = investigate_memory_leak.get_current_state().memory_usage
  log("Hour #{hour}: Memory usage = #{memory_snapshot.total}")
end

# Analyze memory growth patterns
memory_analysis = investigate_memory_leak.analyze_message_flow(
  FlowAnalysisType.memory_patterns
)

memory_leak_report = generate_memory_analysis_report(
  debugger: investigate_memory_leak,
  analysis: memory_analysis,
  leak_indicators: identify_potential_leaks(memory_analysis)
)
```

This time-travel debugging system transforms how developers understand and fix complex issues by providing unprecedented visibility into program execution history and system behavior.