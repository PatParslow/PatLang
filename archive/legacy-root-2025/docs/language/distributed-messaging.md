# Distributed Computing with Messages

## Overview

Patlang's distributed messaging system extends the unified message queue across network boundaries, enabling seamless cluster computing, fault-tolerant distributed applications, and transparent scaling. The system maintains the same simple message passing interface while handling complex distributed computing challenges automatically.

## Table of Contents

1. [Cluster Configuration](#cluster-configuration)
2. [Distributed Work Coordination](#distributed-work-coordination)
3. [Fault Tolerance and Recovery](#fault-tolerance-and-recovery)
4. [Load Balancing Strategies](#load-balancing-strategies)
5. [Network Security](#network-security)
6. [Monitoring and Observability](#monitoring-and-observability)

## Cluster Configuration

### Basic Cluster Setup

```patlang
# Configure distributed cluster
configure distributed_cluster {
  node_id: "primary_node"
  cluster_name: "patlang_cluster_prod"
  
  # Network configuration
  listen_address: "0.0.0.0"
  listen_port: 8080
  discovery_method: "static"  # or "consul", "etcd", "dns"
  
  # Static node discovery
  static_nodes: [
    "node1:192.168.1.10:8080",
    "node2:192.168.1.11:8080", 
    "node3:192.168.1.12:8080"
  ]
  
  # Health checking
  health_check_interval: "30_seconds"
  node_timeout: "60_seconds"
  heartbeat_timeout: "10_seconds"
  
  # Message routing
  replication_factor: 2  # Messages replicated to 2 nodes
  consistency_level: "eventual"  # or "strong"
  
  # Performance tuning
  connection_pool_size: 20
  max_concurrent_requests: 100
  message_batch_size: 50
  
  # Security
  encryption: enabled
  authentication: required
  certificate_path: "/etc/patlang/certs/"
}
```

### Dynamic Node Discovery

```patlang
# Configure dynamic service discovery
configure service_discovery {
  provider: "consul"  # or "etcd", "kubernetes", "dns"
  
  consul: {
    address: "consul.service.local:8500"
    service_name: "patlang-node"
    health_check_path: "/health"
    tags: ["patlang", "compute", "production"]
  }
  
  # Auto-registration
  auto_register: true
  registration_interval: "30_seconds"
  deregistration_on_shutdown: true
  
  # Node metadata
  node_metadata: {
    datacenter: "us-west-2",
    instance_type: "compute.large",
    capabilities: ["cpu_intensive", "memory_large"],
    max_concurrent_tasks: 50
  }
}

# Handle dynamic cluster membership
when cluster: node_joined {
  new_node = event_data.node
  
  log("New node joined cluster: #{new_node.id}")
  
  # Update load balancer
  load_balancer.add_node(new_node)
  
  # Redistribute work if needed
  if should_rebalance_work() then
    activate rebalance_cluster_workload
  end
  
  emit cluster: topology_changed with {
    event_type: "node_added",
    node: new_node,
    cluster_size: cluster.get_node_count()
  }
}

when cluster: node_left {
  departed_node = event_data.node
  
  log("Node left cluster: #{departed_node.id}")
  
  # Remove from load balancer
  load_balancer.remove_node(departed_node)
  
  # Reassign work from departed node
  activate handle_node_departure with departed_node
  
  emit cluster: topology_changed with {
    event_type: "node_removed",
    node: departed_node,
    cluster_size: cluster.get_node_count()
  }
}
```

## Distributed Work Coordination

### Work Distribution Patterns

```patlang
# Distributed work coordinator
make a template called DistributedWorkCoordinator {
  DistributedWorkCoordinator has:
    cluster_nodes - list of ClusterNode
    work_distribution_strategy - DistributionStrategy
    fault_tolerance_enabled - boolean = true
    work_tracking - WorkTracker
    
  # Distribute work across cluster
  distribute_work takes:
    work_items - list of WorkItem
    distribution_options - DistributionOptions = DistributionOptions.default
    
  distribute_work returns: {
    # Determine available nodes
    available_nodes = get_healthy_cluster_nodes()
    
    if available_nodes.is_empty() then
      throw NoAvailableNodesError("No healthy nodes available for work distribution")
    end
    
    # Partition work based on strategy
    work_partitions = partition_work(work_items, available_nodes, work_distribution_strategy)
    
    # Send work to each node
    for each node, work_partition in work_partitions do
      work_batch_id = generate_work_batch_id()
      
      send_message node: process_work_batch with {
        batch_id: work_batch_id,
        work_items: work_partition,
        coordinator_node: current_node(),
        deadline: now() + distribution_options.timeout,
        replication_required: distribution_options.replication_required,
        priority: distribution_options.priority
      }
      
      # Track work assignment
      work_tracking.assign_work(work_batch_id, node, work_partition)
    end
    
    emit distributed_work: initiated with {
      total_work_items: work_items.length,
      participating_nodes: available_nodes.length,
      distribution_strategy: work_distribution_strategy.name,
      estimated_completion: calculate_estimated_completion_time(work_partitions)
    }
  }
  
  # Handle work completion from remote nodes
  when any_node: work_batch_completed {
    batch_info = event_data
    
    # Update work tracking
    work_tracking.mark_batch_completed(batch_info.batch_id, batch_info.results)
    
    # Check if all work is done
    if work_tracking.all_work_completed() then
      final_results = work_tracking.aggregate_all_results()
      
      emit distributed_work: completed with {
        total_results: final_results.length,
        total_processing_time: work_tracking.calculate_total_time(),
        participating_nodes: work_tracking.get_participating_node_count(),
        efficiency_metrics: work_tracking.calculate_efficiency_metrics()
      }
    end
  }
  
  # Handle work progress updates
  when any_node: work_progress {
    progress_info = event_data
    work_tracking.update_progress(progress_info.batch_id, progress_info.progress)
    
    emit distributed_work: progress_update with {
      overall_progress: work_tracking.calculate_overall_progress(),
      estimated_completion: work_tracking.estimate_completion_time()
    }
  }
}

# Map-Reduce pattern implementation
make a template called DistributedMapReduce {
  DistributedMapReduce has:
    coordinator - DistributedWorkCoordinator
    
  # Execute distributed map-reduce operation
  map_reduce takes:
    data_items - list of any
    map_function - Function
    reduce_function - Function
    
  map_reduce returns: {
    # Map phase - distribute mapping work
    map_work_items = data_items.map do |item|
      MapWorkItem.new(
        data: item,
        map_function: map_function,
        work_id: generate_work_id()
      )
    end
    
    # Distribute map work
    coordinator.distribute_work(map_work_items, DistributionOptions.new(
      strategy: DistributionStrategy.data_locality,
      timeout: 5.minutes
    ))
    
    # Collect map results
    map_results = []
    
    when any_node: map_work_completed {
      map_results.add_all(event_data.results)
      
      if map_results.length == data_items.length then
        # Start reduce phase
        activate start_reduce_phase with {
          map_results: map_results,
          reduce_function: reduce_function
        }
      end
    }
  }
  
  start_reduce_phase takes:
    map_results - list of any
    reduce_function - Function
    
  start_reduce_phase returns: {
    # Group map results for reduce phase
    reduce_work_items = group_map_results_for_reduction(map_results)
    
    # Distribute reduce work
    coordinator.distribute_work(reduce_work_items, DistributionOptions.new(
      strategy: DistributionStrategy.balanced,
      timeout: 3.minutes
    ))
    
    # Collect final results
    final_results = []
    
    when any_node: reduce_work_completed {
      final_results.add_all(event_data.results)
      
      if all_reduce_work_completed() then
        # Final aggregation if needed
        aggregated_result = aggregate_reduce_results(final_results)
        
        emit map_reduce: completed with {
          result: aggregated_result,
          total_processing_time: calculate_total_time(),
          map_phase_time: get_map_phase_time(),
          reduce_phase_time: get_reduce_phase_time()
        }
      end
    }
  }
}
```

### Remote Node Work Processing

```patlang
# Remote node work processing
when coordinator_node: process_work_batch {
  batch_data = event_data
  
  try
    log("Processing work batch #{batch_data.batch_id} with #{batch_data.work_items.length} items")
    
    # Process work items (potentially in parallel)
    results = []
    processing_stats = ProcessingStats.new()
    
    # Parallel processing within the node
    batch_data.work_items.in_parallel(max_threads: 4) do |work_item|
      start_time = now()
      
      result = process_single_work_item(work_item)
      processing_time = now() - start_time
      
      results.add(result)
      processing_stats.record_item(work_item, result, processing_time)
      
      # Send progress updates for long-running work
      if batch_data.work_items.length > 10 and results.length % 5 == 0 then
        send_message batch_data.coordinator_node: work_progress with {
          batch_id: batch_data.batch_id,
          completed_items: results.length,
          total_items: batch_data.work_items.length,
          processing_node: current_node(),
          estimated_completion: processing_stats.estimate_completion_time()
        }
      end
    end
    
    # Send completion notification
    send_message batch_data.coordinator_node: work_batch_completed with {
      batch_id: batch_data.batch_id,
      results: results,
      processing_node: current_node(),
      processing_time: processing_stats.total_time,
      completion_timestamp: now(),
      performance_metrics: processing_stats.get_metrics()
    }
    
  catch WorkProcessingError as error
    # Send failure notification
    send_message batch_data.coordinator_node: work_batch_failed with {
      batch_id: batch_data.batch_id,
      error_message: error.message,
      error_type: error.class.name,
      processing_node: current_node(),
      failure_timestamp: now(),
      partial_results: results  # Return any completed work
    }
  end
}

# Handle different types of distributed work
when coordinator_node: process_map_work {
  map_work = event_data
  
  # Apply map function to data
  mapped_results = map_work.data_items.map do |item|
    map_work.map_function.call(item)
  end
  
  send_message map_work.coordinator_node: map_work_completed with {
    work_id: map_work.work_id,
    results: mapped_results,
    processing_node: current_node()
  }
}

when coordinator_node: process_reduce_work {
  reduce_work = event_data
  
  # Apply reduce function to grouped data
  reduced_result = reduce_work.data_groups.reduce do |acc, group|
    reduce_work.reduce_function.call(acc, group)
  end
  
  send_message reduce_work.coordinator_node: reduce_work_completed with {
    work_id: reduce_work.work_id,
    result: reduced_result,
    processing_node: current_node()
  }
}
```

## Fault Tolerance and Recovery

### Circuit Breaker Pattern

```patlang
# Implement circuit breaker for node communication
make a template called CircuitBreaker {
  CircuitBreaker has:
    node - ClusterNode
    state - CircuitBreakerState  # closed, open, half_open
    failure_count - number = 0
    failure_threshold - number = 5
    timeout_duration - duration = 60.seconds
    last_failure_time - time
    success_threshold - number = 3  # For half-open state
    
  # Send message through circuit breaker
  send_with_protection takes:
    message_type - text
    message_data - any
    timeout - duration = 30.seconds
    
  send_with_protection returns: {
    case state
    when CircuitBreakerState.closed
      # Normal operation
      try
        result = send_message_to_node_with_timeout(node, message_type, message_data, timeout)
        reset_failure_count()
        result
        
      catch NodeCommunicationError as error
        record_failure()
        
        if failure_count >= failure_threshold then
          open_circuit()
        end
        
        throw error
      end
      
    when CircuitBreakerState.open
      # Circuit is open, check if timeout has passed
      if now() - last_failure_time > timeout_duration then
        state = CircuitBreakerState.half_open
        # Try the request
        return send_with_protection(message_type, message_data, timeout)
      else
        throw CircuitOpenError("Circuit breaker is open for node #{node.id}")
      end
      
    when CircuitBreakerState.half_open
      # Test if node has recovered
      try
        result = send_message_to_node_with_timeout(node, message_type, message_data, timeout)
        record_success()
        
        if success_count >= success_threshold then
          close_circuit()  # Node has recovered
        end
        
        result
        
      catch NodeCommunicationError as error
        open_circuit()  # Still failing, keep circuit open
        throw error
      end
    end
  }
  
  private
  
  record_failure returns: {
    failure_count = failure_count + 1
    last_failure_time = now()
    
    emit circuit_breaker: failure_recorded with {
      node_id: node.id,
      failure_count: failure_count
    }
  }
  
  record_success returns: {
    success_count = (success_count || 0) + 1
  }
  
  open_circuit returns: {
    state = CircuitBreakerState.open
    last_failure_time = now()
    
    emit circuit_breaker: opened with {
      node_id: node.id,
      failure_count: failure_count,
      timeout_duration: timeout_duration
    }
  }
  
  close_circuit returns: {
    state = CircuitBreakerState.closed
    reset_failure_count()
    success_count = 0
    
    emit circuit_breaker: closed with {
      node_id: node.id
    }
  }
}
```

### Work Reassignment on Node Failure

```patlang
# Handle node failures during work processing
when cluster: node_failed {
  failed_node = event_data.node
  
  log("Node failure detected: #{failed_node.id}")
  
  if fault_tolerance_enabled then
    # Get unfinished work from failed node
    unfinished_work = work_tracking.get_unfinished_work_for_node(failed_node)
    
    if unfinished_work.length > 0 then
      log("Reassigning #{unfinished_work.length} work items from failed node #{failed_node.id}")
      
      # Find alternative nodes
      available_nodes = get_healthy_cluster_nodes().reject { |node| node.id == failed_node.id }
      
      if available_nodes.is_empty() then
        emit cluster: no_nodes_available_for_reassignment with {
          failed_node: failed_node,
          unfinished_work_count: unfinished_work.length
        }
        return
      end
      
      # Reassign work
      redistribute_work(unfinished_work, available_nodes)
      
      emit cluster: work_reassigned with {
        failed_node: failed_node,
        reassigned_work_count: unfinished_work.length,
        target_nodes: available_nodes.map(&:id)
      }
    end
  else
    # Mark work as failed if fault tolerance is disabled
    failed_work = work_tracking.get_all_work_for_node(failed_node)
    work_tracking.mark_work_failed(failed_work, "Node failure: #{failed_node.id}")
    
    emit cluster: work_failed_due_to_node_failure with {
      failed_node: failed_node,
      failed_work_count: failed_work.length
    }
  end
}

# Implement work replication for critical tasks
make a function called send_replicated_work {
  send_replicated_work takes:
    work_item - WorkItem
    replication_factor - number = 2
    
  send_replicated_work returns: {
    available_nodes = get_healthy_cluster_nodes()
    
    if available_nodes.length < replication_factor then
      log("Warning: Not enough nodes for desired replication factor")
      replication_factor = available_nodes.length
    end
    
    # Select nodes for replication
    selected_nodes = select_nodes_for_replication(available_nodes, replication_factor)
    
    replicated_work_id = generate_replicated_work_id()
    
    # Send work to all selected nodes
    selected_nodes.each do |node|
      send_message node: process_replicated_work with {
        work_item: work_item,
        replicated_work_id: replicated_work_id,
        replication_factor: replication_factor,
        coordinator_node: current_node()
      }
    end
    
    # Track replicated work
    work_tracking.track_replicated_work(replicated_work_id, selected_nodes, work_item)
  }
}

# Handle replicated work completion
when any_node: replicated_work_completed {
  completion_info = event_data
  
  work_tracking.record_replica_completion(
    completion_info.replicated_work_id,
    completion_info.processing_node,
    completion_info.result
  )
  
  # Check if we have enough completions (typically just need 1)
  if work_tracking.has_sufficient_replica_completions(completion_info.replicated_work_id) then
    # Cancel remaining replicas
    cancel_remaining_replicas(completion_info.replicated_work_id)
    
    # Use the first successful result
    final_result = work_tracking.get_first_replica_result(completion_info.replicated_work_id)
    
    emit replicated_work: completed with {
      replicated_work_id: completion_info.replicated_work_id,
      result: final_result,
      successful_replicas: work_tracking.get_successful_replica_count(completion_info.replicated_work_id)
    }
  end
}
```

## Load Balancing Strategies

### Intelligent Load Balancing

```patlang
# Advanced load balancing with multiple strategies
make a template called IntelligentLoadBalancer {
  IntelligentLoadBalancer has:
    balancing_strategy - BalancingStrategy
    node_health_monitor - NodeHealthMonitor
    performance_metrics - PerformanceMetrics
    workload_predictor - WorkloadPredictor
    
  # Weighted load balancing based on node capabilities
  weighted_balance takes: work_item - WorkItem returns: ClusterNode {
    available_nodes = node_health_monitor.get_healthy_nodes()
    
    if available_nodes.is_empty() then
      throw NoHealthyNodesError("No healthy nodes available")
    end
    
    # Calculate weights based on multiple factors
    node_weights = calculate_comprehensive_node_weights(available_nodes, work_item)
    
    # Select node based on weights (lower weight = higher preference)
    selected_node = weighted_random_selection(available_nodes, node_weights)
    
    # Update load tracking
    performance_metrics.record_work_assignment(selected_node, work_item)
    
    selected_node
  }
  
  # Capability-based load balancing
  capability_based_balance takes: work_item - WorkItem returns: ClusterNode {
    required_capabilities = work_item.required_capabilities
    
    # Filter nodes by capabilities
    capable_nodes = node_health_monitor.get_nodes_with_capabilities(required_capabilities)
    
    if capable_nodes.is_empty() then
      throw NoCapableNodesError("No nodes with required capabilities: #{required_capabilities}")
    end
    
    # Among capable nodes, select based on current load
    least_loaded_node = capable_nodes.min_by do |node|
      performance_metrics.get_current_load_score(node)
    end
    
    least_loaded_node
  }
  
  # Predictive load balancing
  predictive_balance takes: work_item - WorkItem returns: ClusterNode {
    available_nodes = node_health_monitor.get_healthy_nodes()
    
    # Predict completion times for each node
    predicted_completions = available_nodes.map do |node|
      predicted_time = workload_predictor.predict_completion_time(node, work_item)
      { node: node, predicted_completion: predicted_time }
    end
    
    # Select node with earliest predicted completion
    best_option = predicted_completions.min_by { |option| option[:predicted_completion] }
    best_option[:node]
  }
  
  # Geographic/data locality-aware balancing
  locality_aware_balance takes: work_item - WorkItem returns: ClusterNode {
    data_location = work_item.data_location
    
    if data_location.nil? then
      # Fall back to standard balancing if no data locality info
      return weighted_balance(work_item)
    end
    
    # Find nodes in same region/zone as data
    local_nodes = node_health_monitor.get_nodes_in_location(data_location)
    
    if local_nodes.is_empty() then
      # No local nodes, use closest nodes
      closest_nodes = node_health_monitor.get_closest_nodes_to_location(data_location)
      return weighted_balance_from_candidates(work_item, closest_nodes)
    end
    
    # Select best local node
    weighted_balance_from_candidates(work_item, local_nodes)
  }
  
  private
  
  calculate_comprehensive_node_weights takes:
    nodes - list of ClusterNode
    work_item - WorkItem
    
  calculate_comprehensive_node_weights returns: object {
    weights = {}
    
    for each node in nodes do
      # Collect metrics
      cpu_usage = performance_metrics.get_cpu_usage(node)
      memory_usage = performance_metrics.get_memory_usage(node)
      active_work = performance_metrics.get_active_work_count(node)
      average_response_time = performance_metrics.get_average_response_time(node)
      network_latency = performance_metrics.get_network_latency(node)
      
      # Node-specific factors
      node_capacity = node.metadata.max_concurrent_tasks || 10
      specialization_bonus = calculate_specialization_bonus(node, work_item)
      
      # Calculate composite weight (lower is better)
      weight = (
        (cpu_usage * 0.25) +
        (memory_usage * 0.20) +
        ((active_work / node_capacity) * 0.30) +
        (average_response_time * 0.15) +
        (network_latency * 0.10) -
        (specialization_bonus * 0.20)  # Subtract bonus (making weight lower)
      )
      
      weights[node] = weight
    end
    
    weights
  }
  
  calculate_specialization_bonus takes:
    node - ClusterNode
    work_item - WorkItem
    
  calculate_specialization_bonus returns: number {
    bonus = 0.0
    
    # Check if node specializes in this type of work
    if node.metadata.specializations&.include?(work_item.type) then
      bonus += 0.3
    end
    
    # Check if node has optimal resources for this work
    if work_item.requires_gpu and node.metadata.has_gpu then
      bonus += 0.2
    end
    
    if work_item.requires_large_memory and node.metadata.memory_tier == "large" then
      bonus += 0.2
    end
    
    bonus
  }
}
```

### Auto-Scaling Integration

```patlang
# Auto-scaling based on cluster load
make a template called ClusterAutoScaler {
  ClusterAutoScaler has:
    cluster_manager - ClusterManager
    node_provisioner - NodeProvisioner
    load_balancer - IntelligentLoadBalancer
    scaling_policies - ScalingPolicies
    
  # Monitor cluster load and scale accordingly
  monitor_and_scale returns: {
    while auto_scaling_enabled() do
      cluster_metrics = cluster_manager.get_cluster_metrics()
      
      scaling_decision = evaluate_scaling_decision(cluster_metrics)
      
      case scaling_decision.action
      when ScalingAction.scale_up
        scale_up_cluster(scaling_decision.target_nodes)
      when ScalingAction.scale_down
        scale_down_cluster(scaling_decision.nodes_to_remove)
      when ScalingAction.no_action
        # Continue monitoring
      end
      
      sleep(scaling_policies.evaluation_interval)
    end
  }
  
  evaluate_scaling_decision takes: cluster_metrics - ClusterMetrics returns: ScalingDecision {
    # Calculate cluster-wide resource utilization
    average_cpu = cluster_metrics.average_cpu_usage
    average_memory = cluster_metrics.average_memory_usage
    queue_depth = cluster_metrics.total_queue_depth
    response_time = cluster_metrics.average_response_time
    
    # Check scale-up conditions
    if should_scale_up(average_cpu, average_memory, queue_depth, response_time) then
      target_nodes = calculate_nodes_to_add(cluster_metrics)
      return ScalingDecision.scale_up(target_nodes)
    end
    
    # Check scale-down conditions
    if should_scale_down(average_cpu, average_memory, queue_depth, response_time) then
      nodes_to_remove = identify_nodes_to_remove(cluster_metrics)
      return ScalingDecision.scale_down(nodes_to_remove)
    end
    
    ScalingDecision.no_action()
  }
  
  scale_up_cluster takes: target_node_count - number returns: {
    log("Scaling up cluster by #{target_node_count} nodes")
    
    new_nodes = []
    
    for i in 1..target_node_count do
      # Provision new node
      new_node = node_provisioner.provision_node(NodeSpec.new(
        instance_type: select_optimal_instance_type(),
        region: select_optimal_region(),
        capabilities: determine_needed_capabilities()
      ))
      
      # Configure new node
      configure_node_for_cluster(new_node)
      
      # Add to cluster
      cluster_manager.add_node(new_node)
      
      # Update load balancer
      load_balancer.add_node(new_node)
      
      new_nodes.add(new_node)
      
      emit cluster: node_provisioned with {
        node_id: new_node.id,
        instance_type: new_node.instance_type,
        cluster_size: cluster_manager.get_node_count()
      }
    end
    
    emit cluster: scale_up_completed with {
      added_nodes: new_nodes.map(&:id),
      new_cluster_size: cluster_manager.get_node_count()
    }
  }
  
  scale_down_cluster takes: nodes_to_remove - list of ClusterNode returns: {
    log("Scaling down cluster by removing #{nodes_to_remove.length} nodes")
    
    for each node in nodes_to_remove do
      # Drain work from node gracefully
      drain_node_gracefully(node)
      
      # Remove from load balancer
      load_balancer.remove_node(node)
      
      # Remove from cluster
      cluster_manager.remove_node(node)
      
      # Deprovision node
      node_provisioner.deprovision_node(node)
      
      emit cluster: node_deprovisioned with {
        node_id: node.id,
        cluster_size: cluster_manager.get_node_count()
      }
    end
    
    emit cluster: scale_down_completed with {
      removed_nodes: nodes_to_remove.map(&:id),
      new_cluster_size: cluster_manager.get_node_count()
    }
  }
}
```

## Network Security

### Secure Inter-Node Communication

```patlang
# Configure network security
configure network_security {
  # Encryption
  tls_enabled: true
  tls_version: "1.3"
  cipher_suites: ["TLS_AES_256_GCM_SHA384", "TLS_CHACHA20_POLY1305_SHA256"]
  
  # Authentication
  mutual_tls: true
  certificate_authority: "/etc/patlang/ca.crt"
  node_certificate: "/etc/patlang/node.crt"
  node_private_key: "/etc/patlang/node.key"
  
  # Authorization
  rbac_enabled: true
  node_permissions_file: "/etc/patlang/node-permissions.yaml"
  
  # Network policies
  allowed_source_ips: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  blocked_source_ips: []
  
  # Rate limiting
  rate_limit_per_node: "1000_requests_per_minute"
  burst_limit: 100
  
  # Monitoring
  log_all_connections: true
  alert_on_unauthorized_access: true
}

# Secure message handling
make a template called SecureDistributedMessaging {
  SecureDistributedMessaging has:
    encryption_engine - EncryptionEngine
    authentication_manager - AuthenticationManager
    authorization_engine - AuthorizationEngine
    
  # Send secure message to remote node
  send_secure_message_to_node takes:
    target_node - ClusterNode
    message_type - text
    data - any
    security_level - SecurityLevel = SecurityLevel.standard
    
  send_secure_message_to_node returns: {
    # Authenticate local node
    local_identity = authentication_manager.get_node_identity()
    
    # Check authorization to send to target node
    if not authorization_engine.can_send_to_node(local_identity, target_node, message_type) then
      throw UnauthorizedError("Not authorized to send #{message_type} to #{target_node.id}")
    end
    
    # Create secure message
    secure_message = create_secure_network_message(
      source: local_identity,
      target: target_node,
      type: message_type,
      data: data,
      security_level: security_level
    )
    
    # Encrypt message if required
    if security_level.requires_encryption then
      secure_message.data = encryption_engine.encrypt(
        secure_message.data,
        target_node.public_key
      )
      secure_message.encrypted = true
    end
    
    # Sign message for integrity and authentication
    secure_message.signature = encryption_engine.sign(
      secure_message,
      local_identity.private_key
    )
    
    # Send through secure channel
    send_over_secure_channel(target_node, secure_message)
  }
  
  # Receive and validate secure message
  receive_secure_network_message takes: network_message - NetworkMessage returns: {
    # Verify message signature
    sender_node = cluster_manager.get_node(network_message.source_node_id)
    
    if not encryption_engine.verify_signature(network_message, sender_node.public_key) then
      emit security: message_integrity_failure with {
        source_node: network_message.source_node_id,
        message_id: network_message.id
      }
      throw MessageIntegrityError("Message signature verification failed")
    end
    
    # Check authorization to receive
    local_identity = authentication_manager.get_node_identity()
    
    if not authorization_engine.can_receive_from_node(local_identity, sender_node, network_message.type) then
      emit security: unauthorized_message_received with {
        source_node: sender_node.id,
        message_type: network_message.type
      }
      throw UnauthorizedError("Not authorized to receive #{network_message.type} from #{sender_node.id}")
    end
    
    # Decrypt if encrypted
    if network_message.encrypted then
      network_message.data = encryption_engine.decrypt(
        network_message.data,
        local_identity.private_key
      )
    end
    
    # Log successful message receipt
    emit security: secure_message_received with {
      source_node: sender_node.id,
      message_type: network_message.type,
      timestamp: now()
    }
    
    # Process the validated message
    process_network_message(network_message)
  }
}
```

## Monitoring and Observability

### Cluster Health Monitoring

```patlang
# Comprehensive cluster monitoring
make a template called ClusterMonitor {
  ClusterMonitor has:
    metrics_collector - MetricsCollector
    alert_manager - AlertManager
    dashboard_updater - DashboardUpdater
    
  # Monitor cluster health continuously
  monitor_cluster_health returns: {
    while monitoring_enabled() do
      cluster_health = collect_cluster_health_metrics()
      
      # Update dashboards
      dashboard_updater.update_cluster_dashboard(cluster_health)
      
      # Check for alerts
      check_health_thresholds(cluster_health)
      
      # Emit health metrics
      emit cluster_monitoring: health_update with cluster_health
      
      sleep(monitoring_interval)
    end
  }
  
  collect_cluster_health_metrics returns: ClusterHealth {
    all_nodes = cluster_manager.get_all_nodes()
    
    node_health_data = all_nodes.map do |node|
      collect_node_health(node)
    end
    
    ClusterHealth.new(
      timestamp: now(),
      total_nodes: all_nodes.length,
      healthy_nodes: node_health_data.count { |n| n.status == "healthy" },
      unhealthy_nodes: node_health_data.count { |n| n.status == "unhealthy" },
      node_details: node_health_data,
      
      # Aggregate metrics
      total_cpu_usage: node_health_data.average(&:cpu_usage),
      total_memory_usage: node_health_data.average(&:memory_usage),
      total_network_throughput: node_health_data.sum(&:network_throughput),
      total_active_work: node_health_data.sum(&:active_work_count),
      
      # Performance metrics
      average_response_time: calculate_cluster_average_response_time(),
      total_messages_per_second: calculate_cluster_message_rate(),
      error_rate: calculate_cluster_error_rate(),
      
      # Capacity metrics
      total_capacity: node_health_data.sum(&:max_capacity),
      used_capacity: node_health_data.sum(&:used_capacity),
      capacity_utilization: calculate_capacity_utilization_percentage()
    )
  }
  
  collect_node_health takes: node - ClusterNode returns: NodeHealth {
    try
      # Ping node for basic connectivity
      ping_response = ping_node(node, timeout: 5.seconds)
      
      if not ping_response.success then
        return NodeHealth.unhealthy(node, "Node not responding to ping")
      end
      
      # Collect detailed metrics
      node_metrics = metrics_collector.collect_node_metrics(node)
      
      NodeHealth.new(
        node_id: node.id,
        status: determine_node_status(node_metrics),
        cpu_usage: node_metrics.cpu_usage,
        memory_usage: node_metrics.memory_usage,
        disk_usage: node_metrics.disk_usage,
        network_throughput: node_metrics.network_throughput,
        active_work_count: node_metrics.active_work_count,
        max_capacity: node_metrics.max_capacity,
        used_capacity: node_metrics.used_capacity,
        last_seen: now(),
        uptime: node_metrics.uptime,
        version: node_metrics.patlang_version
      )
      
    catch NodeCommunicationError as error
      NodeHealth.unhealthy(node, "Communication error: #{error.message}")
    end
  }
  
  check_health_thresholds takes: cluster_health - ClusterHealth returns: {
    # Check cluster-wide thresholds
    if cluster_health.healthy_nodes < minimum_healthy_nodes then
      alert_manager.trigger_alert(Alert.new(
        severity: "critical",
        message: "Cluster has only #{cluster_health.healthy_nodes} healthy nodes (minimum: #{minimum_healthy_nodes})",
        cluster_health: cluster_health
      ))
    end
    
    if cluster_health.capacity_utilization > 85 then
      alert_manager.trigger_alert(Alert.new(
        severity: "warning",
        message: "Cluster capacity utilization is #{cluster_health.capacity_utilization}%",
        cluster_health: cluster_health
      ))
    end
    
    if cluster_health.error_rate > 5 then  # 5% error rate
      alert_manager.trigger_alert(Alert.new(
        severity: "warning",
        message: "Cluster error rate is #{cluster_health.error_rate}%",
        cluster_health: cluster_health
      ))
    end
    
    # Check individual node thresholds
    cluster_health.node_details.each do |node_health|
      if node_health.status == "unhealthy" then
        alert_manager.trigger_alert(Alert.new(
          severity: "error",
          message: "Node #{node_health.node_id} is unhealthy: #{node_health.status_reason}",
          node_health: node_health
        ))
      end
    end
  }
}
```

This distributed messaging system provides a robust foundation for building scalable, fault-tolerant distributed applications while maintaining the simplicity of Patlang's unified message passing interface.