# Patlang Language Reference

## Table of Contents

1. [Language Overview](#language-overview)
2. [Design Philosophy](#design-philosophy)
3. [Syntax Reference](#syntax-reference)
4. [Type System](#type-system)
5. [Multi-Paradigm Programming](#multi-paradigm-programming)
6. [Built-in Functions and Standard Library](#built-in-functions-and-standard-library)
7. [Error Handling](#error-handling)
8. [Performance Considerations](#performance-considerations)
9. [Implementation Status](#implementation-status)

---

## Language Overview

Patlang is a multi-paradigm programming language that seamlessly integrates object-oriented programming, functional programming, goal-oriented programming, event-driven programming, and logic programming. It features natural language-inspired syntax designed for expressiveness, readability, and developer productivity.

### Key Features

- **Multi-paradigm integration**: All paradigms work together in unified code
- **Natural language syntax**: Near-English readability with minimal punctuation
- **Type inference**: Hindley-Milner type system with optional annotations
- **Memory safety**: Automatic bounds checking and null safety
- **Goal-oriented programming**: Declarative dependency resolution
- **Event-driven architecture**: First-class events and reactive programming
- **Logic programming**: Integrated facts, rules, and queries
- **Interactive development**: REPL with live code reloading

### Design Goals

- **Expressiveness and Readability**: Support for near-English syntax and intuitive constructs
- **Advanced Feature Integration**: Native support for multiple programming paradigms
- **Performance and Safety**: Efficient execution with integrated security features
- **Interactivity and Self-Hosting**: Interactive development with eventual self-hosting capability
- **Extensibility and Modularity**: Plugin architecture and language extensions

---

## Design Philosophy

### Multi-Paradigm Unity

Patlang's core innovation is the seamless integration of programming paradigms. Rather than forcing developers to choose a single approach, Patlang allows natural transitions between paradigms within the same code:

```patlang
# Example: Payment processing combining all paradigms
make a function called process_payment {
  process_payment takes:
    payment_request - PaymentRequest
    
  process_payment returns: {
    # OOP: Domain modeling
    customer = Customer.find(payment_request.customer_id)
    payment = Payment.new(payment_request.amount, payment_request.currency)
    
    # Functional: Data transformation pipeline
    validated_data = payment_request
      |> validate_payment_method
      |> check_fraud_indicators
      |> verify_customer_status
    
    # Logic programming: Business rules
    query payment_is_allowed(payment, customer) returns:
      customer.account_status == "active" and
      payment.amount <= customer.credit_limit and
      not payment_exceeds_daily_limit(customer, payment.amount)
    end
    
    if payment_is_allowed(payment, customer) then
      # Goal-oriented: Business process
      make a goal called authorize_payment {
        authorize_payment requires:
          validated_payment - Payment
          verified_customer - Customer
          
        authorize_payment is achieved when:
          payment gateway responds and
          transaction is recorded and
          customer is notified
          
        authorize_payment runs: {
          authorization = gateway.authorize(validated_payment)
          
          # Event-driven: Trigger side effects
          emit payment_authorized with [payment, customer, authorization]
          
          authorization
        }
      }
      
      activate authorize_payment with [payment, customer]
    else
      PaymentResult.rejected("Payment not allowed")
    end
  }
}
```

### Natural Language Syntax

Patlang prioritizes readability through natural language constructs:

- **Declarative keywords**: `make`, `called`, `when`, `is`, `becomes`
- **Natural operators**: `is not`, `and`, `or`, `contains`
- **Flexible block styles**: Both `{}` and `begin...end` supported
- **Type annotations**: Optional with `-` syntax (`name - text`)

---

## Syntax Reference

### Program Structure

Every Patlang program consists of statements that can be declarations, assignments, expressions, or control flow constructs.

#### Basic Program Structure

```ebnf
program = { statement } ;
statement = declaration | assignment | expression_statement | control_flow_statement | event_handler | logic_statement | import_statement ;
```

### Lexical Elements

#### Lexer Error Handling

**Important**: The Patlang lexer is designed for robustness and never fails on unrecognized input. When encountering invalid characters or malformed tokens, the lexer returns special token types (UNKNOWN, UNTERMINATED_STRING, etc.) rather than raising exceptions. This enables better error recovery and user experience.

For implementation details, see [`docs/development/lexer-error-handling-specification.md`](../development/lexer-error-handling-specification.md).

#### Comments

```patlang
# Single-line comment
/*
  Multi-line comment
  spans multiple lines
*/
```

#### Identifiers and Keywords

- **Identifiers**: Start with letter, followed by letters, digits, or underscores
- **Reserved words**: `make`, `a`, `an`, `called`, `when`, `if`, `else`, `then`, `end`, `begin`, `for`, `while`, `do`, `function`, `template`, `goal`, `requires`, `ensures`, `achieved`, `runs`, etc.

#### Literals

```patlang
# Numbers
42              # Integer
3.14159         # Float

# Text
"Hello, world!" # String
'c'             # Character

# Boolean and nil
true
false
nil
```

### Declarations

#### Variable Declarations

```patlang
# Basic declarations
make a number called age { age is 25 }
make a text called name { name is "Alice" }
make a boolean called active { active is true }

# Type-inferred declarations
make a variable called count { count is 0 }

# Assignments
age becomes 26
name is "Bob"
active = false
```

#### Function Definitions

```patlang
# Simple function
make a function called square {
  square takes:
    x - number
  square returns:
    x * x
}

# Function with contracts
make a function called divide {
  divide takes:
    dividend - number
    divisor - number
  divide requires:
    divisor is not 0
  divide ensures:
    result is number
  divide returns:
    dividend / divisor
}

# Function with begin...end style
make a function called factorial begin
  factorial takes:
    n - integer
  factorial returns:
    if n <= 1 then 1 else n * factorial(n - 1) end
end
```

#### Class and Template Definitions

```patlang
# Class definition
make a template called Person {
  Person has:
    name - text
    age - number
    email - email = ""
    
  Person maintains:
    age >= 0
    name is not empty
    
  greet takes:
    other - Person
  greet returns:
    "Hello " + other.name + ", I'm " + name
    
  get_info returns:
    "#{name} is #{age} years old"
}

# Inheritance
make a template called Employee {
  Employee inherits from Person
  Employee has:
    employee_id - id
    department - text
    
  get_work_info returns:
    name + " works in " + department
}
```

### Expressions

#### Arithmetic and Logical Operations

```patlang
# Arithmetic
result is (a + b) * c / d
power is base ** exponent

# Logical
is_valid is age >= 18 and name is not empty
can_proceed is has_permission or is_admin

# Comparison
is_equal is first_name == last_name
is_different is value1 != value2
is_older is person1.age > person2.age
```

#### Collections

```patlang
# Arrays (1-indexed)
numbers is [1, 2, 3, 4, 5]
mixed is ["text", 42, true, nil]
nested is [[1, 2], [3, 4]]

# Objects
person is {
  name: "John",
  age: 30,
  address: {
    street: "123 Main St",
    city: "Anytown"
  }
}

# Array access
first is numbers[1]        # First element
last is numbers[-1]        # Last element
slice is numbers[2..4]     # Slice [2, 3, 4]
```

#### String Operations

```patlang
# String concatenation
full_name is first_name + " " + last_name

# String interpolation
greeting is "Hello, #{name}! You are #{age} years old."

# Multi-line strings
poem is """
  Roses are red,
  Violets are blue,
  Patlang is readable,
  And functional too!
"""
```

### Control Flow

#### Conditional Statements

```patlang
# If statements
if age >= 18 then
  print "You are an adult"
elsif age >= 13 then
  print "You are a teenager"
else
  print "You are a child"
end

# Ternary-like expressions
status is if active then "online" else "offline" end
```

#### Loops

```patlang
# While loops
count is 1
while count <= 10 do
  print count
  count becomes count + 1
end

# For loops
for number in [1, 2, 3, 4, 5] do
  print "Number: " + number
end

for each item in shopping_list:
  print "Buy: " + item
```

#### Error Handling

```patlang
try
  result is divide(10, 0)
  print "Result: " + result
catch DivisionByZeroError as error
  print "Cannot divide by zero: " + error.message
catch MathError as error
  print "Math error: " + error.message
finally
  print "Calculation completed"
end

# Throwing errors
if balance < 0 then
  throw InsufficientFundsError("Balance cannot be negative")
end
```

### Functional Programming

#### First-Class Functions and Closures

```patlang
# Lambda expressions
square is |x| x * x
add_numbers is |a, b| a + b

# Higher-order functions
numbers is [1, 2, 3, 4, 5]
doubled is map(numbers, |x| x * 2)
evens is filter(numbers, |x| x % 2 == 0)
sum is reduce(numbers, |acc, x| acc + x, 0)

# Block passing
with_file("data.txt") do |file|
  content is file.read()
  print content
end
```

#### Function Composition

```patlang
# Pipe operator for function composition
result is data
  |> validate_input
  |> transform_data
  |> save_to_database

# Function composition
make a function called compose {
  compose takes:
    f - block
    g - block
  compose returns:
    |x| f(g(x))
}
```

### Goal-Oriented Programming

#### Goal Definitions

```patlang
make a goal called send_email {
  send_email requires:
    recipient - email
    subject - text
    body - text
    
  send_email is achieved when:
    recipient is valid
    subject is not empty
    body is not empty
    
  send_email runs:
    email_service.send(recipient, subject, body)
    log_email_sent(recipient)
}

# Goal dependencies
make a goal called prepare_report {
  prepare_report requires:
    gather_data
    analyze_data
    format_results
    
  prepare_report is achieved when:
    all dependencies are complete
    
  prepare_report runs:
    generate_final_report()
}
```

#### Goal Activation

```patlang
# Activate goals with parameters
activate send_email with ["user@example.com", "Hello", "Message body"]

# Goal activation in expressions
result is activate process_data with [input_data]
```

### Event-Driven Programming

#### Event Handlers

```patlang
# Object events
when user: login is activated {
  print "User logged in: " + user.name
  log_user_activity(user, "login")
}

when form: submit is activated {
  if form.is_valid then
    process_form_data(form)
  else
    show_validation_errors(form.errors)
  end
}

# Simple events
when file_uploaded {
  process_file(uploaded_file)
  send_notification("File processed")
}
```

#### Event Emission

```patlang
# Emit events
emit user_created with new_user
emit data_processed with [processed_data, metadata]

# Event chaining
when data_validated {
  emit processing_started with validated_data
}
```

### Logic Programming

#### Facts and Rules

```patlang
# Facts using natural language
Janet is John's parent.
John is Mary's parent.
Mary is Susan's parent.

# Facts using predicates
parent(janet, john).
parent(john, mary).
parent(mary, susan).

# Rules
relationship X is grandparent of Y requires:
  X is parent of Z and Z is parent of Y.

relationship X is sibling of Y requires:
  Z is parent of X and Z is parent of Y and X is not Y.
```

#### Queries

```patlang
# Query definitions
query find_grandparents
  find_grandparents returns:
    X is grandparent of Y.
end

query are_siblings(A, B)
  are_siblings(A, B) returns:
    A is sibling of B.
end

# Inline queries
query user_can_access(user, resource) returns:
  user.role == "admin" or
  resource.owner_id == user.id or
  user.permissions contains resource.required_permission
end

if user_can_access(current_user, requested_resource) then
  grant_access()
else
  deny_access()
end
```

### Module System

```patlang
# Importing modules
import Math from "std/math"
import { Calculator, Operations } from "utils/calculator"

# Exporting from a module
export make a function called fibonacci {
  fibonacci takes:
    n - integer
  fibonacci returns:
    if n <= 1 then n else fibonacci(n-1) + fibonacci(n-2) end
}

# Namespace usage
result is Math.sqrt(25)
calculator is Calculator.new()
sum is calculator.add(5, 3)
```

---

## Type System

Patlang employs a Hindley-Milner type system extended with constraint-based subtyping to support both parametric polymorphism and object-oriented features.

### Basic Types

```patlang
# Primitive types
number      # Numeric values (integer or float)
integer     # Whole numbers
float       # Floating-point numbers
text        # String values
boolean     # true or false
email       # Email address format
id          # Unique identifier
date        # Date values
time        # Time values
any         # Any type (use sparingly)
```

### Collection Types

```patlang
# List types
list                    # List of any type
list of text           # List of strings
list of number         # List of numbers

# Nested collections
list of list of number # List of number lists
```

### Function Types

```patlang
# Function type annotations
number -> number              # Function taking number, returning number
(number, number) -> number    # Function taking two numbers, returning number
text -> (number -> boolean)   # Curried function
```

### Union Types

```patlang
# Union types for flexibility
text | number           # Either text or number
User | Guest | Admin    # User role types
Response | nil          # Optional response
```

### Generic Types

```patlang
# Generic type definitions
Container[T]           # Generic container
Dictionary[K, V]       # Generic dictionary
Result[T, E]          # Result type with success/error
```

### Type Annotations

```patlang
# Optional type annotations
make a function called process_data {
  process_data takes:
    input - list of text
    processor - (text -> text)
    options - ProcessingOptions | nil
  process_data returns: list of text
  process_data returns: {
    # Function body
  }
}
```

### Type Inference

Patlang automatically infers types when not explicitly specified:

```patlang
# Type inference examples
count is 0                    # Inferred as integer
name is "Alice"              # Inferred as text
active is true               # Inferred as boolean
numbers is [1, 2, 3]         # Inferred as list of integer

# Inference with functions
double is |x| x * 2          # Inferred as number -> number
identity is |x| x            # Inferred as T -> T (generic)
```

### Contract Programming

```patlang
# Pre and post conditions
make a function called withdraw {
  withdraw takes:
    account - BankAccount
    amount - number
    
  withdraw requires:
    amount > 0
    account.balance >= amount
    account.is_active
    
  withdraw ensures:
    account.balance == old(account.balance) - amount
    transaction is logged
    
  withdraw returns: {
    # Implementation
  }
}

# Class invariants
make a template called BankAccount {
  BankAccount has:
    balance - number
    account_number - text
    
  BankAccount maintains:
    balance >= 0
    account_number is not empty
}
```

---

## Multi-Paradigm Programming

Patlang's multi-paradigm integration allows natural transitions between programming styles within the same code. A foundational principle enabling this integration is that **language elements themselves are first-class objects** that can have events attached to them.

### Language Elements as Objects

In Patlang, functions, variables, classes, and other language constructs are objects that can have properties, methods, and events. This enables powerful meta-programming and reactive programming patterns.

#### Functions as Event-Enabled Objects

Functions can have events attached for monitoring and reactive programming:

```patlang
make a function called calculate_total {
  calculate_total takes:
    items - list of number
  calculate_total returns:
    items.reduce(|acc, item| acc + item, 0)
}

# Attach events to the function object
when calculate_total: called {
  log("calculate_total called with #{event_data.arguments.length} arguments")
  emit metrics:function_call with {
    function_name: "calculate_total",
    timestamp: now(),
    arguments: event_data.arguments
  }
}

when calculate_total: completed {
  log("calculate_total returned: #{event_data.result}")
  if event_data.result > 1000 then
    emit business:high_value_transaction with event_data.result
  end
}

when calculate_total: error {
  log("calculate_total failed: #{event_data.error}")
  emit monitoring:function_error with {
    function: "calculate_total",
    error: event_data.error,
    arguments: event_data.arguments
  }
}
```

#### Variables as Reactive Objects

Variables trigger events when their values change, enabling reactive programming:

```patlang
make a number called inventory_count { inventory_count is 100 }

# React to inventory changes
when inventory_count: changed {
  old_value = event_data.old_value
  new_value = event_data.new_value
  
  log("Inventory changed from #{old_value} to #{new_value}")
  
  if new_value < 10 then
    emit inventory:low_stock with {
      item: "inventory_count",
      current_level: new_value,
      threshold: 10
    }
  elsif new_value > old_value then
    emit inventory:restocked with {
      item: "inventory_count",
      added_quantity: new_value - old_value
    }
  end
}

# Variable changes trigger events automatically
inventory_count = 50   # Triggers 'changed' event
inventory_count = 5    # Triggers 'changed' and 'low_stock' events
```

#### Classes as Observable Objects

Classes can monitor instantiation, method calls, and inheritance:

```patlang
make a template called User {
  User has:
    name - text
    email - email
    created_at - time = now()
    
  validate_email returns:
    email.contains("@") and email.contains(".")
}

# Monitor class-level events
when User: instantiated {
  log("New User created: #{event_data.instance.name}")
  emit analytics:user_created with {
    user_id: event_data.instance.id,
    timestamp: event_data.instance.created_at
  }
}

when User: method_called {
  log("Method #{event_data.method_name} called on User")
  emit monitoring:method_usage with {
    class_name: "User",
    method_name: event_data.method_name,
    instance_id: event_data.instance.id
  }
}

# Usage
john = User.new("John Doe", "john@example.com")  # Triggers 'instantiated' event
john.validate_email()                            # Triggers 'method_called' event
```

#### Multi-Paradigm Event Integration

Language element events integrate seamlessly with goals and logic programming:

```patlang
# Goal that responds to function events
make a goal called optimize_performance {
  optimize_performance requires:
    function_metrics - metrics_data
    
  optimize_performance is achieved when:
    average_execution_time < 100  # milliseconds
    
  optimize_performance runs: {
    if function_metrics.execution_time > 200 then
      activate cache_function_results with function_metrics.function_name
    end
  }
}

# Function event triggers goal
when calculate_total: completed {
  if event_data.execution_time > 100 then
    activate optimize_performance with {
      function_name: "calculate_total",
      execution_time: event_data.execution_time
    }
  end
}

# Logic programming with language element facts
when User: instantiated {
  # Assert facts about the new user
  assert user_exists(event_data.instance.id).
  assert user_has_email(event_data.instance.id, event_data.instance.email).
  
  # Query business rules
  query can_send_welcome_email(event_data.instance.id) returns:
    user_exists(UserId) and
    user_has_email(UserId, Email) and
    Email is not empty
  end
  
  if can_send_welcome_email(event_data.instance.id) then
    activate send_welcome_email with event_data.instance
  end
}
```

### Paradigm Integration Patterns

#### OOP + Functional

```patlang
# Object-oriented structure with functional operations
make a template called DataProcessor {
  DataProcessor has:
    transformations - list of (any -> any)
    filters - list of (any -> boolean)
    
  process takes:
    data - list of any
  process returns: {
    # Functional pipeline within OOP context
    data
      |> apply_filters(filters)
      |> apply_transformations(transformations)
      |> validate_results
  }
  
  apply_filters takes:
    filter_list - list of (any -> boolean)
  apply_filters returns: {
    |data| filter_list.reduce(data, |acc, filter| acc.filter(filter))
  }
}
```

#### Goals + Events

```patlang
# Goals that emit events and respond to events
make a goal called process_order {
  process_order requires:
    order - Order
    payment_info - PaymentInfo
    
  process_order is achieved when:
    payment is verified and
    inventory is reserved and
    shipping is scheduled
    
  process_order runs: {
    # Emit events during goal execution
    emit order_processing_started with order
    
    # Process steps
    payment_result is verify_payment(payment_info)
    inventory_result is reserve_inventory(order.items)
    shipping_result is schedule_shipping(order)
    
    emit order_processed with [order, payment_result, inventory_result, shipping_result]
  }
}

# Event handlers that activate goals
when payment: failed is activated {
  activate handle_payment_failure with [event_data.payment, event_data.reason]
}
```

#### Logic + Business Rules

```patlang
# Complex business logic using rule-based programming
make a template called LoanApprovalSystem {
  evaluate_application takes:
    application - LoanApplication
  evaluate_application returns: {
    # Logic programming for complex rule evaluation
    query loan_approved(application) returns:
      credit_score_sufficient(application.credit_score) and
      income_adequate(application.annual_income, application.loan_amount) and
      debt_ratio_acceptable(application.monthly_debt, application.monthly_income) and
      employment_stable(application.employment_history) and
      not bankruptcy_recent(application.credit_history)
    end
    
    if loan_approved(application) then
      LoanDecision.approved(calculate_terms(application))
    else
      LoanDecision.denied(get_denial_reasons(application))
    end
  }
  
  # Define business rule predicates
  credit_score_sufficient takes: score - number
  credit_score_sufficient returns: score >= 650
  
  income_adequate takes: income - number, loan_amount - number
  income_adequate returns: loan_amount / income <= 0.28
}
```

#### Event + Functional Reactive Programming

```patlang
# Reactive streams combining events and functional programming
make a template called DataStream {
  DataStream has:
    transformations - list of (any -> any)
    subscribers - list of (any -> nil)
    
  # Functional reactive programming
  transform takes:
    transformation - (any -> any)
  transform returns: {
    transformations.add(transformation)
    self
  }
  
  filter takes:
    predicate - (any -> boolean)
  filter returns: {
    transformations.add(|data| data.filter(predicate))
    self
  }
  
  subscribe takes:
    handler - (any -> nil)
  subscribe returns: {
    subscribers.add(handler)
    self
  }
}

# Usage with events
data_stream is DataStream.new()
  .transform(|data| data.map(|item| item.to_uppercase))
  .filter(|data| data.length > 0)
  .subscribe(|data| print "Processed: " + data)

when data: received is activated {
  data_stream.emit(event_data)
}
```

### Cross-Paradigm Data Flow

Data flows naturally between paradigms:

1. **OOP → Functional**: Object methods return data that flows into functional pipelines
2. **Functional → Logic**: Transformed data is validated using logic programming rules
3. **Logic → Goals**: Rule outcomes trigger goal activation with validated data
4. **Goals → Events**: Goal completion emits events with result data
5. **Events → OOP**: Event handlers modify object state and call methods

## Internal Message Passing System

Patlang's event-driven programming system extends naturally into a powerful **internal message passing system** that enables cross-thread communication, state persistence, and distributed computing capabilities. The event queue becomes a thread-safe message queue, providing a unified foundation for both local reactivity and distributed communication.

### Core Concepts

The message passing system builds on three fundamental principles:

1. **Event Queue as Message Queue**: The existing event system doubles as a thread-safe message queue
2. **Message Persistence**: Messages can be persisted to storage for replay and state recovery
3. **Cross-Boundary Communication**: Messages can cross thread, process, and network boundaries

### Message Queue Configuration

```patlang
# Configure message queue for persistence and distribution
configure message_queue {
  persistence: enabled
  storage: "patlang_messages.db"
  replay_on_startup: true
  network_enabled: false
  max_queue_size: 10000
  compression: enabled
}

# Enable distributed messaging
configure message_queue {
  network_enabled: true
  cluster_nodes: ["node1:8080", "node2:8080", "node3:8080"]
  node_id: "primary_node"
  heartbeat_interval: 5000  # milliseconds
}
```

### Cross-Thread Communication

Thread-safe message passing enables concurrent programming without traditional locking mechanisms:

```patlang
# Create worker threads with message passing
worker_thread = create_thread {
  # Worker thread listens for work messages
  when main_thread: work_request {
    data = event_data.work_data
    result = process_heavy_computation(data)
    
    # Send result back to main thread
    send_message main_thread: work_complete with {
      original_request_id: event_data.request_id,
      result: result,
      processing_time: calculate_processing_time()
    }
  }
  
  # Handle shutdown messages
  when main_thread: shutdown {
    cleanup_resources()
    send_message main_thread: shutdown_complete
    exit_thread()
  }
}

# Main thread sends work to worker
request_id = generate_unique_id()
send_message worker_thread: work_request with {
  request_id: request_id,
  work_data: large_dataset,
  priority: "high"
}

# Main thread handles completion
when worker_thread: work_complete {
  if event_data.original_request_id == request_id then
    process_worker_result(event_data.result)
    log("Work completed in #{event_data.processing_time}ms")
  end
}
```

### Message Persistence and Replay

Messages can be persisted for state recovery and time-travel debugging:

```patlang
# Enable selective message persistence
configure message_persistence {
  persist_pattern: ["state:*", "business:*", "audit:*"]
  exclude_pattern: ["debug:*", "metrics:*"]
  retention_period: "30_days"
  compression_level: 6
}

# Save application state through messages
save_application_state returns: {
  state_data = {
    variables: get_all_variables(),
    objects: serialize_all_objects(),
    thread_states: get_thread_states(),
    timestamp: now()
  }
  
  # Persist as message for replay
  send_message system: state_checkpoint with {
    checkpoint_id: generate_checkpoint_id(),
    state_data: state_data,
    persistence: required
  }
}

# Restore application state from message queue
restore_application_state takes: checkpoint_id returns: {
  # Replay messages from specific checkpoint
  checkpoint_message = find_persisted_message("system:state_checkpoint", checkpoint_id)
  
  if checkpoint_message then
    restore_variables(checkpoint_message.state_data.variables)
    restore_objects(checkpoint_message.state_data.objects)
    restore_thread_states(checkpoint_message.state_data.thread_states)
    
    # Replay subsequent messages
    replay_messages_after(checkpoint_message.timestamp)
    
    emit system: state_restored with checkpoint_id
  else
    throw StateRestorationError("Checkpoint #{checkpoint_id} not found")
  end
}
```

### Distributed Computing Support

Messages can cross process and network boundaries for distributed applications:

```patlang
# Distributed work coordination
make a goal called distribute_workload {
  distribute_workload requires:
    work_items - list of WorkItem
    target_nodes - list of text
    
  distribute_workload is achieved when:
    all work items are assigned and
    all nodes have acknowledged assignment
    
  distribute_workload runs: {
    work_distribution = partition_work(work_items, target_nodes)
    
    for each node, work_chunk in work_distribution do
      send_message node: process_work_chunk with {
        chunk_id: generate_chunk_id(),
        work_items: work_chunk,
        callback_node: current_node(),
        deadline: now() + 5.minutes
      }
    end
    
    emit workload: distributed with {
      total_items: work_items.length,
      node_count: target_nodes.length,
      distribution_time: now()
    }
  }
}

# Remote node processing
when any_node: process_work_chunk {
  chunk_data = event_data
  
  try
    results = chunk_data.work_items.map(|item| process_work_item(item))
    
    # Send results back to coordinator
    send_message chunk_data.callback_node: work_chunk_complete with {
      chunk_id: chunk_data.chunk_id,
      results: results,
      processing_node: current_node(),
      completion_time: now()
    }
    
  catch WorkProcessingError as error
    # Send error back to coordinator
    send_message chunk_data.callback_node: work_chunk_failed with {
      chunk_id: chunk_data.chunk_id,
      error: error.message,
      processing_node: current_node(),
      failure_time: now()
    }
  end
}

# Coordinator handles results
when any_node: work_chunk_complete {
  update_work_progress(event_data.chunk_id, event_data.results)
  
  if all_work_chunks_complete() then
    final_results = aggregate_all_results()
    emit workload: completed with {
      total_results: final_results.length,
      processing_time: calculate_total_processing_time(),
      participating_nodes: get_participating_nodes()
    }
  end
}
```

### Message Routing and Filtering

Advanced message routing enables complex communication patterns:

```patlang
# Set up message routing rules
configure message_routing {
  # Route high-priority messages to dedicated queue
  route_if: { message.priority == "high" }
  to_queue: "high_priority_queue"
  
  # Route messages by type to different handlers
  route_pattern: "business:*"
  to_handlers: ["business_logic_handler", "analytics_handler"]
  
  # Route cross-node messages through network layer
  route_if: { message.target_node != current_node() }
  to_gateway: "network_gateway"
}

# Message filtering for security and performance
configure message_filtering {
  # Security filters
  reject_if: { not authorized_sender(message.sender) }
  reject_pattern: ["admin:*"]  # Unless sender has admin role
  
  # Performance filters
  throttle_pattern: "metrics:*"
  max_rate: "100_per_second"
  
  # Content filters
  transform_if: { message.contains_sensitive_data }
  transformer: "data_anonymizer"
}
```

### Time-Travel Debugging

Message persistence enables powerful debugging capabilities:

```patlang
# Debug mode with enhanced message tracking
configure debug_mode {
  trace_all_messages: true
  capture_stack_traces: true
  record_variable_states: true
  enable_time_travel: true
}

# Time-travel debugging session
debug_session = create_debug_session {
  start_time: "2024-01-15 14:30:00"
  end_time: "2024-01-15 14:35:00"
  focus_threads: ["main_thread", "worker_thread_1"]
  track_variables: ["user_count", "error_rate"]
}

# Step through message history
debug_session.step_forward()  # Next message in timeline
debug_session.step_backward() # Previous message in timeline
debug_session.jump_to_message(message_id)  # Jump to specific message

# Replay with breakpoints
debug_session.set_breakpoint(
  condition: { message.type == "error" },
  action: { inspect_system_state() }
)

debug_session.replay_from_checkpoint("checkpoint_1")
```

### Performance Considerations

Message passing performance optimizations:

```patlang
# Configure performance optimizations
configure message_performance {
  # Batch small messages for efficiency
  batch_size: 100
  batch_timeout: "10ms"
  
  # Use circular buffers for high-throughput scenarios
  use_ring_buffer: true
  ring_buffer_size: 1000000
  
  # Compress large messages
  compression_threshold: "1KB"
  compression_algorithm: "lz4"
  
  # Priority queues for urgent messages
  priority_levels: ["low", "normal", "high", "urgent"]
  urgent_queue_size: 1000
}

# Monitor message queue performance
when message_queue: performance_metrics {
  metrics = event_data.metrics
  
  if metrics.queue_depth > 10000 then
    emit alerts: high_queue_depth with metrics
    activate scale_message_processing
  end
  
  if metrics.message_latency > 100 then  # milliseconds
    emit alerts: high_message_latency with metrics
    activate optimize_message_routing
  end
}
```

### Integration with Existing Event System

The message passing system seamlessly extends the existing event system:

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

### Related Documentation

For comprehensive coverage of Patlang's message passing capabilities, see the following specialized documentation:

- **[Message Passing System Overview](message-passing-system.md)**: Core concepts, basic usage, and cross-thread communication patterns
- **[Message Persistence and State Management](message-persistence.md)**: State checkpoints, message replay, storage backends, and recovery scenarios
- **[Time-Travel Debugging](time-travel-debugging.md)**: Debug sessions, stepping through message history, breakpoints, and flow analysis
- **[Distributed Computing with Messages](distributed-messaging.md)**: Cluster configuration, work coordination, fault tolerance, and load balancing
- **[Message Performance and Scalability](message-performance.md)**: High-performance patterns, memory optimization, latency tuning, and benchmarking
- **[Message Security](message-security.md)**: Authentication, authorization, encryption, content filtering, and audit compliance

These documents provide detailed implementation guidance, advanced patterns, and real-world examples for building robust message-driven applications in Patlang.

---

## Built-in Functions and Standard Library

### Core Functions

#### Text/String Operations

```patlang
# String manipulation
length(text)                    # Get string length
substring(text, start, end)     # Extract substring
contains(text, substring)       # Check if string contains substring
starts_with(text, prefix)       # Check if string starts with prefix
ends_with(text, suffix)         # Check if string ends with suffix
to_uppercase(text)              # Convert to uppercase
to_lowercase(text)              # Convert to lowercase
trim(text)                      # Remove whitespace
split(text, delimiter)          # Split string into list
join(list, delimiter)           # Join list into string
```

#### Collection Operations

```patlang
# List operations
length(list)                    # Get list length
is_empty(list)                  # Check if list is empty
first(list)                     # Get first element
last(list)                      # Get last element
append(list, item)              # Add item to end
prepend(list, item)             # Add item to beginning
slice(list, start, end)         # Extract sublist
reverse(list)                   # Reverse list order

# Higher-order functions
map(list, function)             # Transform each element
filter(list, predicate)         # Filter elements by condition
reduce(list, function, initial) # Reduce to single value
find(list, predicate)           # Find first matching element
any(list, predicate)            # Check if any element matches
all(list, predicate)            # Check if all elements match
```

#### Mathematical Operations

```patlang
# Basic math
abs(number)                     # Absolute value
min(a, b)                       # Minimum of two values
max(a, b)                       # Maximum of two values
sqrt(number)                    # Square root
power(base, exponent)           # Exponentiation
round(number, decimals)         # Round to decimal places
floor(number)                   # Round down
ceil(number)                    # Round up

# List math
sum(list)                       # Sum of all elements
average(list)                   # Average of all elements
```

#### Type Conversion

```patlang
# Type conversions
to_text(value)                  # Convert to string
to_number(text)                 # Convert string to number
to_integer(number)              # Convert to integer
to_boolean(value)               # Convert to boolean
type_of(value)                  # Get type name
```

#### I/O Operations

```patlang
# Console I/O
print(message)                  # Print to console
read_line()                     # Read line from input
read_number()                   # Read number from input

# File I/O
read_file(path)                 # Read entire file
write_file(path, content)       # Write content to file
append_file(path, content)      # Append content to file
file_exists(path)               # Check if file exists
```

### Standard Library Modules

#### Math Module

```patlang
import Math from "std/math"

# Constants
Math.PI                         # π constant
Math.E                          # e constant

# Trigonometric functions
Math.sin(angle)                 # Sine
Math.cos(angle)                 # Cosine
Math.tan(angle)                 # Tangent
Math.asin(value)                # Arcsine
Math.acos(value)                # Arccosine
Math.atan(value)                # Arctangent

# Logarithmic functions
Math.log(value)                 # Natural logarithm
Math.log10(value)               # Base-10 logarithm
Math.exp(value)                 # e^value
```

#### DateTime Module

```patlang
import DateTime from "std/datetime"

# Current time
DateTime.now()                  # Current date and time
DateTime.today()                # Current date
DateTime.utc_now()              # Current UTC time

# Date creation
DateTime.new(year, month, day)
DateTime.parse("2023-12-25")

# Date operations
date.add_days(days)
date.add_months(months)
date.add_years(years)
date.format("YYYY-MM-DD")
```

#### Collections Module

```patlang
import Collections from "std/collections"

# Set operations
set is Collections.Set.new([1, 2, 3, 2])
set.add(4)
set.contains(2)
set.union(other_set)
set.intersection(other_set)

# Dictionary operations
dict is Collections.Dictionary.new()
dict.set("key", "value")
dict.get("key")
dict.keys()
dict.values()
```

---

## Error Handling

### Exception Types

Patlang provides a hierarchy of built-in exception types:

```patlang
# Built-in exception hierarchy
Error
├── SystemError
│   ├── MemoryError
│   ├── StackOverflowError
│   └── ResourceError
├── RuntimeError
│   ├── NullPointerError
│   ├── IndexOutOfBoundsError
│   ├── TypeMismatchError
│   └── DivisionByZeroError
├── ValidationError
│   ├── ArgumentError
│   ├── FormatError
│   └── RangeError
├── IOError
│   ├── FileNotFoundError
│   ├── PermissionError
│   └── NetworkError
└── LogicError
    ├── ContractViolationError
    ├── PreConditionError
    └── PostConditionError
```

### Try-Catch-Finally

```patlang
try
  # Risky operations
  result is process_data(input)
  save_result(result)
  
catch ValidationError as error
  print "Validation failed: " + error.message
  use_default_values()
  
catch IOError as error
  print "I/O error: " + error.message
  retry_operation()
  
catch Error as error
  print "Unexpected error: " + error.message
  log_error(error)
  
finally
  cleanup_resources()
  print "Operation completed"
end
```

### Custom Exceptions

```patlang
# Define custom exception types
make a template called BusinessLogicError {
  BusinessLogicError inherits from Error
  BusinessLogicError has:
    business_code - text
    context - any
    
  BusinessLogicError.new takes:
    message - text
    business_code - text
    context - any = nil
}

# Throw custom exceptions
if account.balance < withdrawal_amount then
  throw BusinessLogicError.new(
    "Insufficient funds",
    "INSUFFICIENT_FUNDS",
    { balance: account.balance, requested: withdrawal_amount }
  )
end
```

### Goal-Based Error Recovery

```patlang
# Error recovery using goals
when database: connection_failed is activated {
  make a goal called restore_connection {
    restore_connection requires:
      connection_config - DatabaseConfig
      retry_count - integer = 0
      
    restore_connection is achieved when:
      database connection is restored or
      max retries exceeded
      
    restore_connection runs: {
      if retry_count >= 3 then
        escalate_to_operations()
      else
        try
          database.reconnect(connection_config)
        catch ConnectionError
          sleep(retry_count * 2)
          activate restore_connection with [connection_config, retry_count + 1]
        end
      end
    }
  }
  
  activate restore_connection with [database.config]
}
```

---

## Performance Considerations

### Type Inference Optimization

- **Constraint simplification**: Reduces computational overhead during type checking
- **Incremental inference**: Supports responsive interactive development
- **Monomorphization**: Generic functions are specialized at compile time when possible

### Memory Management

- **Hybrid approach**: Combines garbage collection with region-based allocation
- **Escape analysis**: Stack allocation for short-lived objects
- **Object pooling**: Reuse objects to reduce GC pressure

### Event System Performance

- **Non-blocking I/O**: High throughput asynchronous operations
- **Event handler inlining**: Reduces dispatch overhead for hot paths
- **Event pooling**: Minimizes allocation overhead

### Goal Engine Optimization

- **Dependency caching**: Cache dependency graph analysis
- **Incremental updates**: Only recompute affected goals
- **Parallel execution**: Execute independent goals concurrently

---

## Implementation Status

Patlang is currently in active development with the following implementation roadmap:

### Phase 1: Core Infrastructure (Weeks 1-4) ✅
- **Week 1**: Complete lexer implementation
- **Week 2**: Basic recursive descent parser
- **Week 3**: AST construction and visitor pattern
- **Week 4**: Tree-walking interpreter for expressions

### Phase 2: Object-Oriented Foundation (Weeks 5-8) 🚧
- **Week 5**: Basic object system and property access
- **Week 6**: Class definitions and inheritance
- **Week 7**: Advanced OOP features (constructors, access control)
- **Week 8**: Environment and scope management

### Phase 3: Control Flow and Functions (Weeks 9-12) 📋
- **Week 9**: Control structures (if, while, for)
- **Week 10**: Function system with parameters
- **Week 11**: Closures and first-class functions
- **Week 12**: Exception handling system

### Phase 4: Multi-Paradigm Features (Weeks 13-18) 📋
- **Week 13-14**: Goal-oriented programming system
- **Week 15**: Event-driven programming
- **Week 16**: Logic programming basics
- **Week 17**: Type inference engine
- **Week 18**: Multi-paradigm integration testing

### Phase 5: Advanced Features (Weeks 19-22) 📋
- **Week 19-20**: Interactive REPL implementation
- **Week 21**: Standard library development
- **Week 22**: Self-hosting preparation

### Implementation Approach

- **Bootstrap Language**: Ruby (for initial implementation)
- **Target**: Self-hosting Patlang compiler/interpreter
- **Architecture**: Tree-walking interpreter transitioning to bytecode
- **Testing**: Comprehensive test suite with TDD approach

---

## See Also

- **[Getting Started Guide](getting-started.md)**: Tutorial and learning progression
- **Syntax Specification**: Complete EBNF grammar definition
- **Interpreter Architecture**: Technical implementation details
- **Real-World Examples**: Comprehensive application examples

---

*This reference is part of the official Patlang documentation. For the latest updates and examples, visit the project repository.*