# Message Persistence and State Management

## Overview

Patlang's message persistence system enables state recovery, time-travel debugging, and audit trails by persisting messages to durable storage. This system transforms the message queue into a powerful state management and debugging tool.

## Table of Contents

1. [Persistence Configuration](#persistence-configuration)
2. [State Checkpoints](#state-checkpoints)
3. [Message Replay](#message-replay)
4. [Storage Backends](#storage-backends)
5. [Recovery Scenarios](#recovery-scenarios)

## Persistence Configuration

### Basic Persistence Setup

```patlang
# Configure message persistence
configure message_persistence {
  storage_backend: "sqlite"  # or "postgres", "file", "memory"
  database_path: "patlang_messages.db"
  
  # Persistence patterns - what to persist
  persist_patterns: [
    "state:*",         # All state-related messages
    "business:*",      # Business logic messages
    "audit:*",         # Audit trail messages
    "checkpoint:*"     # Checkpoint messages
  ]
  
  exclude_patterns: [
    "debug:*",         # Exclude debug messages
    "metrics:*",       # Exclude metrics (too frequent)
    "heartbeat:*"      # Exclude heartbeat messages
  ]
  
  # Retention policy
  retention_days: 30
  compression: enabled
  encryption: enabled  # For sensitive data
  
  # Performance settings
  batch_size: 100
  flush_interval: "5_seconds"
  index_fields: ["timestamp", "type", "source", "target"]
}
```

### Selective Persistence

```patlang
# Persist only critical messages
configure selective_persistence {
  # High-priority messages
  persist_if: { message.priority == "urgent" or message.priority == "high" }
  
  # Business-critical operations
  persist_if: { message.type.starts_with("payment") or message.type.starts_with("order") }
  
  # Error and exception messages
  persist_if: { message.type.contains("error") or message.type.contains("failed") }
  
  # Large data transfers (for debugging)
  persist_if: { message.data.size > 1.megabyte }
  
  # Explicit persistence requests
  persist_if: { message.persistence_required == true }
}

# Force persistence for specific messages
send_message audit_service: security_breach with {
  incident_data: breach_details,
  persistence: required,  # Force persistence regardless of patterns
  retention: "indefinite"  # Keep forever
}
```

## State Checkpoints

### Creating Application State Checkpoints

```patlang
# Create comprehensive state checkpoint
make a function called create_state_checkpoint {
  create_state_checkpoint takes:
    checkpoint_name - text
    include_options - CheckpointOptions = CheckpointOptions.default
    
  create_state_checkpoint returns: {
    checkpoint_id = generate_checkpoint_id()
    
    # Gather system state
    state_data = {
      checkpoint_id: checkpoint_id,
      checkpoint_name: checkpoint_name,
      timestamp: now(),
      variables: serialize_variables(include_options.variables),
      objects: serialize_objects(include_options.objects),
      thread_states: serialize_thread_states(include_options.threads),
      message_queue_states: serialize_message_queues(),
      active_goals: serialize_active_goals(),
      event_subscriptions: serialize_event_handlers(),
      function_states: serialize_function_metadata(),
      performance_metrics: capture_performance_snapshot()
    }
    
    # Persist checkpoint as a special message
    send_message system: checkpoint_created with {
      checkpoint_data: state_data,
      persistence: required,
      priority: "high",
      retention: "long_term"
    }
    
    log("State checkpoint '#{checkpoint_name}' created with ID: #{checkpoint_id}")
    emit system: checkpoint_created with checkpoint_id
    
    checkpoint_id
  }
}

# Automatic checkpoint creation
configure automatic_checkpoints {
  # Time-based checkpoints
  create_every: "1_hour"
  
  # Event-based checkpoints
  create_on: ["application:startup", "application:shutdown", "critical:error"]
  
  # Condition-based checkpoints
  create_when: { total_processed_messages % 10000 == 0 }
  
  # Performance-based checkpoints
  create_when: { memory_usage > 80.percent }
  
  # Naming pattern
  name_pattern: "auto_checkpoint_#{timestamp}_#{trigger_reason}"
  
  # Retention
  keep_last: 24  # Keep last 24 automatic checkpoints
  cleanup_older_than: "7_days"
}

# Business logic checkpoints
when order: payment_completed {
  # Create checkpoint after successful payment
  create_state_checkpoint("payment_completed_#{order.id}", CheckpointOptions.new(
    include_order_state: true,
    include_payment_state: true,
    include_inventory_state: true
  ))
}

when daily_report: generated {
  # Daily business checkpoint
  create_state_checkpoint("daily_checkpoint_#{today()}", CheckpointOptions.business_state)
}
```

### Checkpoint Management

```patlang
# Checkpoint management utilities
make a template called CheckpointManager {
  CheckpointManager has:
    storage_backend - PersistenceBackend
    retention_policy - RetentionPolicy
    
  # List available checkpoints
  list_checkpoints takes:
    filter_criteria - CheckpointFilter = CheckpointFilter.all
    
  list_checkpoints returns: list of CheckpointInfo {
    checkpoints = storage_backend.query_checkpoints(filter_criteria)
    
    checkpoints.map do |checkpoint|
      CheckpointInfo.new(
        id: checkpoint.checkpoint_id,
        name: checkpoint.checkpoint_name,
        timestamp: checkpoint.timestamp,
        size: checkpoint.data_size,
        variables_count: checkpoint.variables.length,
        objects_count: checkpoint.objects.length,
        threads_count: checkpoint.thread_states.length
      )
    end
  }
  
  # Find checkpoint by criteria
  find_checkpoint takes:
    criteria - CheckpointSearchCriteria
    
  find_checkpoint returns: CheckpointData {
    matching_checkpoints = storage_backend.search_checkpoints(criteria)
    
    if matching_checkpoints.is_empty() then
      throw CheckpointNotFoundError("No checkpoints match the criteria")
    end
    
    # Return the most recent matching checkpoint
    latest_checkpoint = matching_checkpoints.max_by { |cp| cp.timestamp }
    deserialize_checkpoint(latest_checkpoint)
  }
  
  # Delete old checkpoints
  cleanup_checkpoints returns: {
    expired_checkpoints = find_expired_checkpoints(retention_policy)
    
    expired_checkpoints.each do |checkpoint|
      storage_backend.delete_checkpoint(checkpoint.id)
      log("Deleted expired checkpoint: #{checkpoint.name}")
    end
    
    emit checkpoint_manager: cleanup_completed with {
      deleted_count: expired_checkpoints.length
    }
  }
}
```

## Message Replay

### Comprehensive Replay System

```patlang
# Restore from checkpoint with optional replay
make a function called restore_from_checkpoint {
  restore_from_checkpoint takes:
    checkpoint_id - text
    restore_options - RestoreOptions = RestoreOptions.default
    
  restore_from_checkpoint returns: {
    # Find the checkpoint message
    checkpoint_message = message_persistence.find_checkpoint(checkpoint_id)
    
    if checkpoint_message.is_nil() then
      throw CheckpointNotFoundError("Checkpoint #{checkpoint_id} not found")
    end
    
    checkpoint_data = checkpoint_message.data.checkpoint_data
    
    emit system: restore_started with {
      checkpoint_id: checkpoint_id,
      checkpoint_name: checkpoint_data.checkpoint_name,
      checkpoint_timestamp: checkpoint_data.timestamp
    }
    
    # Restore system state components
    if restore_options.restore_variables then
      restore_variables(checkpoint_data.variables)
      log("Variables restored")
    end
    
    if restore_options.restore_objects then
      restore_objects(checkpoint_data.objects)
      log("Objects restored")
    end
    
    if restore_options.restore_threads then
      restore_thread_states(checkpoint_data.thread_states)
      log("Thread states restored")
    end
    
    if restore_options.restore_message_queues then
      restore_message_queue_states(checkpoint_data.message_queue_states)
      log("Message queue states restored")
    end
    
    if restore_options.restore_goals then
      restore_active_goals(checkpoint_data.active_goals)
      log("Active goals restored")
    end
    
    if restore_options.restore_event_handlers then
      restore_event_subscriptions(checkpoint_data.event_subscriptions)
      log("Event subscriptions restored")
    end
    
    # Optionally replay messages after checkpoint
    if restore_options.replay_messages then
      replayed_count = replay_messages_after_checkpoint(
        checkpoint_data.timestamp,
        restore_options.replay_filter
      )
      log("Replayed #{replayed_count} messages")
    end
    
    emit system: state_restored with {
      checkpoint_id: checkpoint_id,
      checkpoint_name: checkpoint_data.checkpoint_name,
      restore_timestamp: now(),
      restore_options: restore_options
    }
    
    log("System state restored from checkpoint: #{checkpoint_data.checkpoint_name}")
  }
}

# Advanced message replay with filtering
make a function called replay_messages_after_checkpoint {
  replay_messages_after_checkpoint takes:
    checkpoint_timestamp - time
    replay_filter - ReplayFilter = ReplayFilter.default
    
  replay_messages_after_checkpoint returns: number {
    # Get messages after checkpoint
    messages = message_persistence.get_messages_after(
      checkpoint_timestamp,
      filter: replay_filter
    )
    
    log("Found #{messages.length} messages to replay")
    
    replayed_count = 0
    
    # Sort messages by timestamp for correct order
    sorted_messages = messages.sort_by { |msg| msg.timestamp }
    
    sorted_messages.each do |message|
      # Check if message should be replayed
      if should_replay_message(message, replay_filter) then
        replay_single_message(message)
        replayed_count = replayed_count + 1
        
        # Progress reporting for large replays
        if replayed_count % 1000 == 0 then
          emit replay: progress with {
            replayed_count: replayed_count,
            total_count: sorted_messages.length,
            current_message: message
          }
        end
      end
    end
    
    replayed_count
  }
}

# Selective message replay
make a template called SelectiveReplay {
  SelectiveReplay has:
    replay_filter - ReplayFilter
    state_validator - StateValidator
    
  # Replay only specific message types
  replay_message_type takes:
    message_type_pattern - text
    start_time - time
    end_time - time = now()
    
  replay_message_type returns: {
    messages = message_persistence.get_messages_by_type(
      message_type_pattern,
      start_time,
      end_time
    )
    
    log("Replaying #{messages.length} messages of type '#{message_type_pattern}'")
    
    messages.each do |message|
      replay_single_message(message)
    end
    
    emit replay: type_replay_completed with {
      message_type: message_type_pattern,
      count: messages.length
    }
  }
  
  # Replay messages from specific source
  replay_from_source takes:
    source_identifier - text
    start_time - time
    end_time - time = now()
    
  replay_from_source returns: {
    messages = message_persistence.get_messages_from_source(
      source_identifier,
      start_time,
      end_time
    )
    
    log("Replaying #{messages.length} messages from source '#{source_identifier}'")
    
    messages.each do |message|
      # Validate message before replay
      if state_validator.is_safe_to_replay(message) then
        replay_single_message(message)
      else
        log("Skipped unsafe message: #{message.id}")
      end
    end
  }
  
  # Conditional replay based on system state
  replay_with_conditions takes:
    conditions - ReplayConditions
    start_time - time
    end_time - time = now()
    
  replay_with_conditions returns: {
    messages = message_persistence.get_messages_between(start_time, end_time)
    
    replayed_count = 0
    skipped_count = 0
    
    messages.each do |message|
      if conditions.should_replay(message, get_current_system_state()) then
        replay_single_message(message)
        replayed_count = replayed_count + 1
      else
        skipped_count = skipped_count + 1
      end
    end
    
    emit replay: conditional_replay_completed with {
      replayed_count: replayed_count,
      skipped_count: skipped_count
    }
  }
}
```

## Storage Backends

### SQLite Backend (Default)

```patlang
# SQLite storage configuration
configure sqlite_storage {
  database_path: "patlang_messages.db"
  journal_mode: "WAL"  # Write-Ahead Logging for better concurrency
  synchronous: "NORMAL"  # Balance between safety and performance
  cache_size: "64MB"
  
  # Table configuration
  messages_table: "messages"
  checkpoints_table: "checkpoints"
  indexes: ["timestamp", "type", "source", "target", "priority"]
  
  # Partitioning for large datasets
  partition_by: "timestamp"
  partition_interval: "1_month"
  
  # Compression
  compress_data: true
  compression_algorithm: "zstd"
  compression_level: 6
}
```

### PostgreSQL Backend

```patlang
# PostgreSQL storage for production environments
configure postgresql_storage {
  connection_string: "postgresql://user:password@localhost:5432/patlang_messages"
  
  # Connection pooling
  max_connections: 20
  min_connections: 5
  connection_timeout: "30_seconds"
  
  # Table configuration
  schema: "patlang"
  messages_table: "messages"
  checkpoints_table: "checkpoints"
  
  # Performance optimization
  use_prepared_statements: true
  batch_insert_size: 1000
  
  # High availability
  read_replicas: ["replica1:5432", "replica2:5432"]
  failover_enabled: true
}
```

### File-Based Storage

```patlang
# Simple file-based storage for development
configure file_storage {
  storage_directory: "message_storage"
  file_format: "jsonl"  # JSON Lines format
  
  # File organization
  organize_by: "date"  # or "type", "source"
  max_file_size: "100MB"
  compression: enabled
  
  # Indexing
  create_indexes: true
  index_format: "btree"
}
```

## Recovery Scenarios

### Crash Recovery

```patlang
# Automatic crash recovery on startup
make a function called perform_crash_recovery {
  perform_crash_recovery returns: {
    log("Starting crash recovery process...")
    
    # Find the most recent checkpoint before crash
    last_checkpoint = find_most_recent_checkpoint()
    
    if last_checkpoint.is_nil() then
      log("No checkpoints found, starting fresh")
      return
    end
    
    log("Found checkpoint: #{last_checkpoint.name} from #{last_checkpoint.timestamp}")
    
    # Restore from checkpoint
    restore_from_checkpoint(last_checkpoint.id, RestoreOptions.crash_recovery)
    
    # Replay messages since checkpoint
    crash_time = detect_crash_time()
    
    if crash_time > last_checkpoint.timestamp then
      log("Replaying messages from #{last_checkpoint.timestamp} to #{crash_time}")
      
      replay_filter = ReplayFilter.new(
        exclude_patterns: ["debug:*", "metrics:*"],
        include_critical_only: true
      )
      
      replayed_count = replay_messages_after_checkpoint(
        last_checkpoint.timestamp,
        replay_filter
      )
      
      log("Crash recovery completed. Replayed #{replayed_count} messages.")
    end
    
    emit system: crash_recovery_completed with {
      checkpoint_used: last_checkpoint,
      messages_replayed: replayed_count
    }
  }
}

# Data corruption recovery
make a function called recover_from_corruption {
  recover_from_corruption takes:
    corruption_start_time - time
    
  recover_from_corruption returns: {
    log("Starting data corruption recovery from #{corruption_start_time}")
    
    # Find last good checkpoint before corruption
    good_checkpoint = find_last_good_checkpoint_before(corruption_start_time)
    
    if good_checkpoint.is_nil() then
      throw RecoveryError("No good checkpoint found before corruption time")
    end
    
    # Restore from good checkpoint
    restore_from_checkpoint(good_checkpoint.id, RestoreOptions.full_restore)
    
    # Rebuild state from verified messages only
    verified_messages = get_verified_messages_after(good_checkpoint.timestamp)
    
    verified_messages.each do |message|
      if verify_message_integrity(message) then
        replay_single_message(message)
      else
        log("Skipped corrupted message: #{message.id}")
      end
    end
    
    log("Data corruption recovery completed")
  }
}
```

### Partial Recovery

```patlang
# Recover specific subsystems only
make a function called partial_recovery {
  partial_recovery takes:
    subsystem - text
    recovery_point - time
    
  partial_recovery returns: {
    case subsystem
    when "user_management"
      recover_user_system(recovery_point)
    when "payment_processing"
      recover_payment_system(recovery_point)
    when "inventory_management"
      recover_inventory_system(recovery_point)
    when "analytics"
      recover_analytics_system(recovery_point)
    else
      throw UnsupportedSubsystemError("Unknown subsystem: #{subsystem}")
    end
  }
}

make a function called recover_user_system {
  recover_user_system takes: recovery_point - time returns: {
    log("Recovering user management system to #{recovery_point}")
    
    # Find user-related messages
    user_messages = message_persistence.get_messages_by_pattern(
      "user:*",
      recovery_point,
      now()
    )
    
    # Reset user system state
    reset_user_system_state()
    
    # Replay user messages in order
    user_messages.sort_by(&:timestamp).each do |message|
      if message.type.starts_with("user:") then
        replay_single_message(message)
      end
    end
    
    # Validate user system integrity
    validate_user_system_state()
    
    log("User system recovery completed")
  }
}
```

This persistence system provides robust state management capabilities that enable reliable applications, comprehensive debugging, and disaster recovery scenarios.