# Patlang Message Passing System

## Overview

The Patlang Message Passing System extends the language's event-driven architecture into a unified message queue system that enables seamless communication across threads, processes, and network boundaries while providing state persistence and time-travel debugging capabilities.

## Table of Contents

1. [Core Architecture](#core-architecture)
2. [Basic Message Passing](#basic-message-passing)
3. [Cross-Thread Communication](#cross-thread-communication)
4. [Message Configuration](#message-configuration)
5. [Integration with Events](#integration-with-events)
6. [Related Documentation](#related-documentation)

## Core Architecture

### Event Queue as Message Queue

The message passing system leverages Patlang's existing event-driven architecture by extending the event queue to function as a thread-safe, persistent message queue:

```patlang
# Basic message passing configuration
configure message_system {
  mode: "unified_event_message_queue"
  persistence: enabled
  thread_safety: enforced
  cross_process: enabled
  network_layer: optional
}

# The event system automatically handles message routing
when any_source: any_message_type {
  # This handler can receive both local events and remote messages
  handle_unified_communication(event_data)
}
```

### Message Structure

Every message in the system contains comprehensive metadata for routing, persistence, and debugging:

```patlang
# Message structure (automatically generated)
make a template called PatlangMessage {
  PatlangMessage has:
    id - text                    # Unique message identifier
    source - MessageEndpoint     # Source thread/process/node
    target - MessageEndpoint     # Target thread/process/node  
    type - text                  # Message type (e.g., "work:request")
    data - any                   # Message payload
    timestamp - time             # Creation timestamp
    priority - MessagePriority   # urgent, high, normal, low
    persistence_required - boolean
    routing_metadata - object    # Routing information
    processing_metadata - object # Performance and debugging data
    correlation_id - text        # For request/response correlation
    timeout - duration           # Message expiration time
    retry_count - number         # Delivery attempt counter
}
```

## Basic Message Passing

### Simple Thread-to-Thread Communication

```patlang
# Create worker thread with message handling
worker_thread = create_thread "data_processor" {
  # Handle work requests
  when main_thread: process_data {
    data = event_data.payload
    result = perform_computation(data)
    
    # Send result back
    send_message main_thread: computation_complete with {
      request_id: event_data.request_id,
      result: result,
      processing_time: calculate_time()
    }
  }
}

# Main thread sends work
request_id = generate_unique_id()
send_message worker_thread: process_data with {
  request_id: request_id,
  payload: large_dataset
}

# Handle response
when worker_thread: computation_complete {
  if event_data.request_id == request_id then
    process_results(event_data.result)
  end
}
```

### Message Priorities and Routing

```patlang
# Send high-priority message
send_message worker_thread: urgent_task with {
  data: critical_data,
  priority: "urgent",
  timeout: 10.seconds
}

# Send with persistence requirement
send_message audit_thread: security_event with {
  event_data: sensitive_operation,
  persistence: required,
  audit_level: "high"
}
```

## Cross-Thread Communication

### Actor Model Implementation

```patlang
# Create an actor-like processor
make a template called DataProcessor {
  DataProcessor has:
    id - text
    processing_thread - Thread
    state - ProcessorState
    
  DataProcessor.new takes: processor_id - text
  DataProcessor.new returns: {
    processor = DataProcessor.create()
    processor.id = processor_id
    processor.state = ProcessorState.idle
    
    # Create dedicated thread
    processor.processing_thread = create_thread "processor_#{processor_id}" {
      processor.setup_message_handlers()
      processor.run_processing_loop()
    }
    
    processor
  }
  
  setup_message_handlers returns: {
    # Handle work requests
    when any_source: work_request {
      if state == ProcessorState.idle then
        state = ProcessorState.processing
        process_work_item(event_data)
        state = ProcessorState.idle
      else
        # Reject if busy
        send_message event_data.sender: work_rejected with {
          reason: "processor_busy",
          processor_id: id
        }
      end
    }
    
    # Handle status queries
    when any_source: status_query {
      send_message event_data.sender: status_response with {
        processor_id: id,
        state: state,
        uptime: calculate_uptime()
      }
    }
  }
}

# Use the processor
processor = DataProcessor.new("proc_001")

send_message processor.processing_thread: work_request with {
  payload: work_data,
  sender: current_thread(),
  deadline: now() + 30.seconds
}
```

### Thread Pool Pattern

```patlang
# Simple thread pool with message-based work distribution
make a template called SimpleThreadPool {
  SimpleThreadPool has:
    workers - list of Thread
    coordinator - Thread
    
  SimpleThreadPool.new takes: pool_size - number
  SimpleThreadPool.new returns: {
    pool = SimpleThreadPool.create()
    pool.workers = []
    
    # Create worker threads
    for i in 1..pool_size do
      worker = create_thread "worker_#{i}" {
        while true do
          when coordinator: work_assignment {
            result = execute_work(event_data.work_item)
            send_message coordinator: work_completed with {
              worker_id: current_thread().id,
              result: result
            }
          }
        end
      }
      pool.workers.add(worker)
    end
    
    # Create coordinator
    pool.coordinator = create_thread "coordinator" {
      available_workers = pool.workers.copy()
      work_queue = []
      
      while true do
        when any_source: submit_work {
          if available_workers.length > 0 then
            worker = available_workers.pop()
            send_message worker: work_assignment with event_data
          else
            work_queue.add(event_data)
          end
        }
        
        when any_worker: work_completed {
          worker = event_data.sender
          available_workers.add(worker)
          
          # Assign queued work if any
          if work_queue.length > 0 then
            next_work = work_queue.shift()
            available_workers.pop()  # Remove worker again
            send_message worker: work_assignment with next_work
          end
        }
      end
    }
    
    pool
  }
  
  submit_work takes: work_item - any returns: {
    send_message coordinator: submit_work with { work_item: work_item }
  }
}
```

## Message Configuration

### Queue Configuration

```patlang
# Configure message queue behavior
configure message_queue {
  # Basic settings
  max_queue_size: 10000
  persistence: enabled
  compression: enabled
  
  # Thread safety
  lock_free: enabled
  numa_aware: true
  
  # Performance
  batch_processing: enabled
  batch_size: 100
  batch_timeout: "10ms"
  
  # Storage
  storage_backend: "sqlite"
  storage_path: "messages.db"
  retention_days: 30
}
```

### Routing Rules

```patlang
# Configure message routing
configure message_routing {
  # Priority routing
  route_if: { priority == "urgent" }
  to_queue: "urgent_queue"
  
  # Pattern-based routing
  route_pattern: "analytics:*"
  to_handlers: ["metrics_collector", "business_intelligence"]
  
  # Cross-boundary routing
  route_if: { target.contains(":") }
  to: "network_gateway"
  
  # Conditional routing
  route_if: { data.size > 1.megabyte }
  to: "large_message_handler"
}
```

### Filtering and Security

```patlang
# Configure message filtering
configure message_filtering {
  # Security filters
  reject_if: { not authorized_sender(message.sender) }
  reject_pattern: ["admin:*"]  # Unless authorized
  
  # Performance filters
  throttle_pattern: "metrics:*"
  max_rate: "100_per_second"
  
  # Content filters
  transform_if: { message.contains_sensitive_data }
  transformer: "data_anonymizer"
}
```

## Integration with Events

### Seamless Event-Message Integration

```patlang
# Events automatically become messages when crossing boundaries
when user: login is activated {
  # Local event handling
  update_user_session(user)
  
  # Cross-thread message for analytics
  send_message analytics_thread: user_login with {
    user_id: user.id,
    login_time: now(),
    session_id: generate_session_id()
  }
  
  # Cross-process message for audit
  send_message audit_service: login_event with {
    user_id: user.id,
    ip_address: user.ip_address,
    login_time: now()
  }
}

# Language element events can trigger messages
when calculate_total: completed {
  # Local performance monitoring
  track_function_performance("calculate_total", event_data.execution_time)
  
  # Send performance data to monitoring service
  if event_data.execution_time > 100 then
    send_message monitoring_service: slow_function with {
      function_name: "calculate_total",
      execution_time: event_data.execution_time,
      arguments: event_data.arguments,
      node_id: current_node()
    }
  end
}
```

### Message-to-Event Conversion

```patlang
# Messages can trigger local events when received
configure message_to_event_conversion {
  # Convert certain message types back to events
  convert_pattern: "event:*"
  strip_prefix: "event:"
  emit_as_local_event: true
}

# Automatic conversion example
when remote_service: event:user_updated {
  # This message is automatically converted to a local event
  # and triggers existing event handlers
}

# Which triggers existing event handlers:
when user: updated {
  # This handler receives the converted event
  refresh_user_display(event_data.user)
}
```

## Related Documentation

- **[Message Persistence and State Management](message-persistence.md)**: Detailed coverage of state persistence, checkpoints, and replay
- **[Distributed Computing with Messages](distributed-messaging.md)**: Network communication, cluster coordination, and fault tolerance
- **[Time-Travel Debugging](time-travel-debugging.md)**: Using message history for debugging and analysis
- **[Message Performance and Scalability](message-performance.md)**: High-performance patterns and optimization strategies
- **[Message Security](message-security.md)**: Security, authentication, and safe message handling

## Quick Start Example

Here's a complete example showing the basics of the message passing system:

```patlang
# Create a simple producer-consumer system
consumer_thread = create_thread "consumer" {
  processed_count = 0
  
  when producer: work_item {
    item = event_data.item
    result = process_item(item)
    processed_count = processed_count + 1
    
    send_message producer: item_processed with {
      item_id: item.id,
      result: result,
      processed_count: processed_count
    }
  }
  
  when producer: shutdown {
    log("Consumer processed #{processed_count} items")
    send_message producer: consumer_shutdown
  }
}

# Producer thread
producer_thread = create_thread "producer" {
  work_items = generate_work_items(100)
  completed_items = 0
  
  # Send work to consumer
  work_items.each do |item|
    send_message consumer_thread: work_item with { item: item }
  end
  
  # Handle completion
  when consumer_thread: item_processed {
    completed_items = completed_items + 1
    log("Item #{event_data.item_id} processed. Total: #{completed_items}")
    
    if completed_items == work_items.length then
      send_message consumer_thread: shutdown
    end
  }
  
  when consumer_thread: consumer_shutdown {
    log("All work completed!")
  }
}
```

This example demonstrates the core concepts of the message passing system and shows how it integrates naturally with Patlang's event-driven architecture.