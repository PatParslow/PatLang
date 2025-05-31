# Patlang Interpreter Architecture Specification

## Table of Contents
1. [Overview](#overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Core Components](#core-components)
4. [Multi-Paradigm Integration](#multi-paradigm-integration)
5. [AST Node Hierarchy](#ast-node-hierarchy)
6. [Type System Design](#type-system-design)
7. [Memory Management Strategy](#memory-management-strategy)
8. [Implementation Roadmap](#implementation-roadmap)
9. [Ruby Implementation Strategies](#ruby-implementation-strategies)
10. [Performance Considerations](#performance-considerations)
11. [Integration Points for Advanced Features](#integration-points-for-advanced-features)

## Overview

This document specifies the technical architecture for implementing the Patlang interpreter in Ruby. The design supports Patlang's multi-paradigm nature, integrating object-oriented programming, functional programming, goal-oriented programming, event systems, and logic programming in a unified execution environment.

### Design Goals
- **Multi-paradigm unity**: Seamless integration of OOP, functional, goal-oriented, event-driven, and logic programming
- **Ruby bootstrap**: Pure Ruby implementation without external dependencies for initial bootstrap
- **Self-hosting preparation**: Architecture designed to support eventual self-hosting in Patlang
- **Incremental implementation**: Modular design allowing feature-by-feature development
- **Performance foundation**: Clean architecture supporting future optimization

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         INPUT LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│ Source Code → Lexer → Token Stream                              │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                        PARSING LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│ Recursive Descent Parser → Abstract Syntax Tree (AST)           │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                       ANALYSIS LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│ Type Inference Engine ← → Semantic Analyzer                     │
│           ↓                        ↓                            │
│      Annotated AST ← ← ← ← ← ← ← ← ← ┘                           │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                      EXECUTION LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│              Tree-Walking Interpreter                           │
│  ┌─────────────┬──────────────┬──────────────┬──────────────┐   │
│  │Environment  │ Event System │ Goal Engine  │Logic Engine  │   │
│  │& Scope Mgmt │              │              │              │   │
│  └─────────────┴──────────────┴──────────────┴──────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                       RUNTIME LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│ Object System │ Memory Mgmt │ Dependency Resolver │ I/O Loop    │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│                      INTERFACE LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│ Interactive REPL              │ Output/Results                   │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Lexer/Tokenizer Design

The lexer converts Patlang source code into a stream of tokens, handling the language's natural English-like syntax.

```ruby
# Core token types for Patlang
class TokenType
  # Literals
  INTEGER = 'INTEGER'
  FLOAT = 'FLOAT'
  STRING = 'STRING'
  BOOLEAN = 'BOOLEAN'
  NIL = 'NIL'
  
  # Identifiers and keywords
  IDENTIFIER = 'IDENTIFIER'
  
  # Natural language operators
  IS = 'IS'
  BECOMES = 'BECOMES'
  IS_NOT = 'IS_NOT'
  AND = 'AND'
  OR = 'OR'
  NOT = 'NOT'
  
  # Structural keywords
  MAKE = 'MAKE'
  A = 'A'
  AN = 'AN'
  CALLED = 'CALLED'
  WHEN = 'WHEN'
  THEN = 'THEN'
  END = 'END'
  BEGIN = 'BEGIN'
  
  # Goal-oriented keywords
  REQUIRES = 'REQUIRES'
  ENSURES = 'ENSURES'
  ACHIEVED = 'ACHIEVED'
  RUNS = 'RUNS'
  
  # Delimiters
  LPAREN = 'LPAREN'
  RPAREN = 'RPAREN'
  LBRACE = 'LBRACE'
  RBRACE = 'RBRACE'
  LBRACKET = 'LBRACKET'
  RBRACKET = 'RBRACKET'
  
  # Special
  EOF = 'EOF'
  NEWLINE = 'NEWLINE'
end

class Token
  attr_reader :type, :value, :line, :column
  
  def initialize(type, value, line, column)
    @type = type
    @value = value
    @line = line
    @column = column
  end
end

class Lexer
  def initialize(source)
    @source = source
    @position = 0
    @line = 1
    @column = 1
    @current_char = @source[@position]
  end
  
  def tokenize
    tokens = []
    while @current_char
      case
      when whitespace?
        skip_whitespace
      when @current_char == '#'
        skip_comment
      when letter?
        tokens << handle_identifier_or_keyword
      when digit?
        tokens << handle_number
      when @current_char == '"'
        tokens << handle_string
      else
        tokens << handle_single_char
      end
    end
    tokens << Token.new(TokenType::EOF, nil, @line, @column)
    tokens
  end
  
  private
  
  def handle_identifier_or_keyword
    start_pos = @position
    start_col = @column
    
    value = ''
    while @current_char && (letter? || digit? || @current_char == '_')
      value += @current_char
      advance
    end
    
    # Handle multi-word operators/keywords
    if peek_for_multiword(value)
      next_word = consume_next_word
      value = "#{value} #{next_word}"
    end
    
    type = keyword_type(value) || TokenType::IDENTIFIER
    Token.new(type, value, @line, start_col)
  end
  
  def keyword_type(value)
    case value.downcase
    when 'make' then TokenType::MAKE
    when 'a' then TokenType::A
    when 'an' then TokenType::AN
    when 'called' then TokenType::CALLED
    when 'when' then TokenType::WHEN
    when 'is' then TokenType::IS
    when 'becomes' then TokenType::BECOMES
    when 'is not' then TokenType::IS_NOT
    when 'and' then TokenType::AND
    when 'or' then TokenType::OR
    when 'not' then TokenType::NOT
    when 'requires' then TokenType::REQUIRES
    when 'ensures' then TokenType::ENSURES
    when 'achieved' then TokenType::ACHIEVED
    when 'runs' then TokenType::RUNS
    when 'true', 'false' then TokenType::BOOLEAN
    when 'nil' then TokenType::NIL
    else nil
    end
  end
end
```

### 2. Parser Architecture (Recursive Descent)

The parser implements a recursive descent strategy optimized for Patlang's natural language constructs.

```ruby
class Parser
  def initialize(tokens)
    @tokens = tokens
    @current = 0
  end
  
  def parse
    statements = []
    while !at_end?
      stmt = statement
      statements << stmt if stmt
    end
    ProgramNode.new(statements)
  end
  
  private
  
  def statement
    case current_token.type
    when TokenType::MAKE
      make_declaration
    when TokenType::WHEN
      event_handler
    when TokenType::IF
      if_statement
    when TokenType::IDENTIFIER
      if check_assignment?
        assignment_statement
      else
        expression_statement
      end
    else
      expression_statement
    end
  end
  
  def make_declaration
    consume(TokenType::MAKE)
    article = consume_article  # 'a' or 'an'
    declaration_type = consume_declaration_type
    consume(TokenType::CALLED)
    name = consume(TokenType::IDENTIFIER)
    body = block_or_begin_end
    
    case declaration_type.value
    when 'function'
      parse_function(name, body)
    when 'class', 'template'
      parse_class(name, body)
    when 'goal'
      parse_goal(name, body)
    when 'list'
      parse_list(name, body)
    end
  end
  
  def parse_function(name, body)
    # Parse function signature and contracts
    signature = extract_function_signature(body)
    contracts = extract_contracts(body)
    function_body = extract_function_body(body)
    
    FunctionNode.new(
      name: name,
      parameters: signature[:parameters],
      return_type: signature[:return_type],
      contracts: contracts,
      body: function_body
    )
  end
  
  def parse_goal(name, body)
    requirements = extract_goal_requirements(body)
    conditions = extract_achievement_conditions(body)
    actions = extract_goal_actions(body)
    
    GoalNode.new(
      name: name,
      requirements: requirements,
      conditions: conditions,
      actions: actions
    )
  end
  
  def event_handler
    consume(TokenType::WHEN)
    event_spec = parse_event_specification
    handler_body = block_or_begin_end
    
    EventHandlerNode.new(event_spec, handler_body)
  end
  
  # Expression parsing with operator precedence
  def expression
    logical_or
  end
  
  def logical_or
    expr = logical_and
    
    while match(TokenType::OR)
      operator = previous_token
      right = logical_and
      expr = BinaryOpNode.new(expr, operator, right)
    end
    
    expr
  end
  
  def logical_and
    expr = equality
    
    while match(TokenType::AND)
      operator = previous_token
      right = equality
      expr = BinaryOpNode.new(expr, operator, right)
    end
    
    expr
  end
  
  def equality
    expr = comparison
    
    while match(TokenType::IS, TokenType::IS_NOT)
      operator = previous_token
      right = comparison
      expr = BinaryOpNode.new(expr, operator, right)
    end
    
    expr
  end
end
```

## Multi-Paradigm Integration

The architecture's key innovation is the unified execution model that allows seamless interaction between different programming paradigms. This is fundamentally enabled by treating **language elements themselves as first-class objects** that can have events, properties, and methods attached to them.

### Language Elements as Objects Architecture

The core architectural principle is that functions, variables, classes, and other language constructs are objects in the runtime system. This enables powerful meta-programming capabilities and seamless paradigm integration.

#### Language Element Object Model

```ruby
class LanguageElement < PatlangObject
  attr_accessor :element_type, :name, :metadata, :event_subscriptions
  
  def initialize(element_type, name)
    super()
    @element_type = element_type  # :function, :variable, :class, etc.
    @name = name
    @metadata = {}
    @event_subscriptions = {}
    @execution_context = nil
  end
  
  # Language elements can have events attached
  def attach_event_handler(event_name, handler)
    @event_subscriptions[event_name] ||= []
    @event_subscriptions[event_name] << handler
  end
  
  # Emit events when language element is used
  def emit_element_event(event_name, event_data)
    handlers = @event_subscriptions[event_name] || []
    handlers.each do |handler|
      begin
        handler.call(event_data, @execution_context)
      rescue => e
        # Handle event handler errors gracefully
        @execution_context&.handle_event_error(e, event_name, handler)
      end
    end
  end
  
  # Track usage metrics
  def track_usage(usage_type, context)
    @metadata[:usage_count] ||= 0
    @metadata[:usage_count] += 1
    @metadata[:last_used] = Time.now
    
    emit_element_event(usage_type, {
      element: self,
      context: context,
      timestamp: Time.now,
      usage_count: @metadata[:usage_count]
    })
  end
end

class FunctionElement < LanguageElement
  attr_accessor :parameters, :body, :return_type, :contracts
  
  def initialize(name, parameters, body, return_type = nil)
    super(:function, name)
    @parameters = parameters
    @body = body
    @return_type = return_type
    @contracts = []
  end
  
  def call(args, context)
    @execution_context = context
    
    # Emit 'called' event
    call_event_data = {
      function: self,
      arguments: args,
      timestamp: Time.now,
      call_stack: context.call_stack.dup
    }
    emit_element_event(:called, call_event_data)
    
    begin
      # Execute function body
      start_time = Time.now
      result = execute_function_body(args, context)
      execution_time = Time.now - start_time
      
      # Emit 'completed' event
      completed_event_data = call_event_data.merge({
        result: result,
        execution_time: execution_time
      })
      emit_element_event(:completed, completed_event_data)
      
      track_usage(:function_called, context)
      result
      
    rescue => error
      # Emit 'error' event
      error_event_data = call_event_data.merge({
        error: error,
        error_type: error.class.name
      })
      emit_element_event(:error, error_event_data)
      
      raise error
    end
  end
  
  private
  
  def execute_function_body(args, context)
    # Create function scope
    func_scope = context.environment.create_child_scope
    
    # Bind parameters
    @parameters.zip(args).each do |param, arg|
      func_scope.bind(param.name, arg)
    end
    
    # Execute with function scope
    context.with_scope(func_scope) do
      context.evaluate(@body)
    end
  end
end

class VariableElement < LanguageElement
  attr_accessor :value, :type_annotation, :observers
  
  def initialize(name, initial_value = nil, type_annotation = nil)
    super(:variable, name)
    @value = initial_value
    @type_annotation = type_annotation
    @observers = []
  end
  
  def set_value(new_value, context)
    @execution_context = context
    old_value = @value
    
    # Type checking if annotation exists
    if @type_annotation && !type_compatible?(new_value, @type_annotation)
      raise TypeError.new("Value #{new_value} is not compatible with type #{@type_annotation}")
    end
    
    @value = new_value
    
    # Emit 'changed' event
    change_event_data = {
      variable: self,
      old_value: old_value,
      new_value: new_value,
      timestamp: Time.now
    }
    emit_element_event(:changed, change_event_data)
    
    # Notify observers (for reactive programming)
    @observers.each do |observer|
      observer.notify_change(self, old_value, new_value, context)
    end
    
    track_usage(:variable_changed, context)
    new_value
  end
  
  def get_value(context)
    @execution_context = context
    
    # Emit 'accessed' event
    access_event_data = {
      variable: self,
      value: @value,
      timestamp: Time.now
    }
    emit_element_event(:accessed, access_event_data)
    
    track_usage(:variable_accessed, context)
    @value
  end
  
  def add_observer(observer)
    @observers << observer
  end
  
  private
  
  def type_compatible?(value, type_annotation)
    # Simple type checking - expand as needed
    case type_annotation.name
    when 'number'
      value.is_a?(Numeric)
    when 'text'
      value.is_a?(String)
    when 'boolean'
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    else
      true  # Unknown types pass for now
    end
  end
end

class ClassElement < LanguageElement
  attr_accessor :fields, :methods, :superclass, :instances
  
  def initialize(name, fields = [], methods = [], superclass = nil)
    super(:class, name)
    @fields = fields
    @methods = methods
    @superclass = superclass
    @instances = []
  end
  
  def instantiate(args, context)
    @execution_context = context
    
    # Create new instance
    instance = PatlangObject.new(self)
    
    # Initialize fields with default values
    @fields.each do |field|
      instance.set_property(field.name, field.default_value)
    end
    
    # Track instance
    @instances << instance
    
    # Emit 'instantiated' event
    instantiation_event_data = {
      class: self,
      instance: instance,
      arguments: args,
      timestamp: Time.now,
      instance_count: @instances.length
    }
    emit_element_event(:instantiated, instantiation_event_data)
    
    # Call constructor if exists
    if has_constructor?
      constructor = find_method('initialize')
      constructor.call([instance] + args, context)
    end
    
    track_usage(:class_instantiated, context)
    instance
  end
  
  def method_called(method_name, instance, args, context)
    # Emit 'method_called' event on the class
    method_call_event_data = {
      class: self,
      method_name: method_name,
      instance: instance,
      arguments: args,
      timestamp: Time.now
    }
    emit_element_event(:method_called, method_call_event_data)
  end
  
  private
  
  def has_constructor?
    @methods.any? { |method| method.name == 'initialize' }
  end
  
  def find_method(name)
    @methods.find { |method| method.name == name }
  end
end
```

### Enhanced Unified Object Model

The unified object model is extended to support language elements as first-class objects:

```ruby
class PatlangObject
  attr_accessor :type, :properties, :methods, :goals, :event_handlers, :logic_facts, :language_element
  
  def initialize(type = nil)
    @type = type
    @properties = {}        # OOP: object state
    @methods = {}          # OOP: behavior
    @goals = {}            # Goal-oriented: associated goals
    @event_handlers = {}   # Event-driven: event subscriptions
    @logic_facts = {}      # Logic: associated facts
    @contracts = {}        # Contract programming: pre/post conditions
    @language_element = nil # Reference to language element if this object represents one
  end
  
  # Factory method for creating language element objects
  def self.create_language_element(element_type, name, **options)
    obj = new(element_type)
    
    case element_type
    when :function
      obj.language_element = FunctionElement.new(name, options[:parameters], options[:body], options[:return_type])
    when :variable
      obj.language_element = VariableElement.new(name, options[:initial_value], options[:type_annotation])
    when :class
      obj.language_element = ClassElement.new(name, options[:fields], options[:methods], options[:superclass])
    end
    
    # Language elements are automatically event-enabled
    obj.setup_language_element_events
    obj
  end
  
  # Set up default event handling for language elements
  def setup_language_element_events
    return unless @language_element
    
    # Forward language element events to object's event system
    @language_element.attach_event_handler(:called) do |event_data|
      emit_object_event(:language_element_called, event_data)
    end
    
    @language_element.attach_event_handler(:changed) do |event_data|
      emit_object_event(:language_element_changed, event_data)
    end
    
    @language_element.attach_event_handler(:instantiated) do |event_data|
      emit_object_event(:language_element_instantiated, event_data)
    end
  end
  
  # Unified method dispatch - handles all paradigms
  def call_method(name, args, context)
    method = find_method(name)
    
    case method
    when PatlangFunction
      # Functional paradigm: method as first-class function
      method.call(self, args, context)
    when PatlangGoal
      # Goal-oriented: method triggers goal achievement
      context.goal_engine.activate_goal_with_args(method, args)
    when PatlangEventHandler
      # Event-driven: method handles events
      method.handle_event(args.first, context)
    else
      # Standard OOP method call
      execute_standard_method(method, args, context)
    end
  end
  
  # Cross-paradigm state management
  def set_property(name, value, context)
    old_value = @properties[name]
    @properties[name] = value
    
    # Trigger cross-paradigm effects
    trigger_property_change_effects(name, old_value, value, context)
  end
  
  private
  
  def trigger_property_change_effects(name, old_value, new_value, context)
    # Event system: emit property change event
    event = PropertyChangeEvent.new(self, name, old_value, new_value)
    context.event_system.emit(event)
    
    # Goal system: check if change affects goal conditions
    context.goal_engine.check_goal_conditions_after_change(self, name, new_value)
    
    # Logic system: update facts
    context.logic_engine.update_facts_for_property(self, name, new_value)
    
    # Contract system: verify invariants
    verify_object_invariants(context)
  end
end
```

### Execution Context Integration

```ruby
class ExecutionContext
  attr_accessor :environment, :goal_engine, :event_system, :logic_engine, :type_system
  
  def initialize
    @environment = Environment.new
    @goal_engine = GoalEngine.new(self)
    @event_system = EventSystem.new(self)
    @logic_engine = LogicEngine.new(self)
    @type_system = TypeSystem.new
    @call_stack = []
  end
  
  def evaluate(ast_node)
    case ast_node
    when LiteralNode
      create_literal_object(ast_node)
      
    when IdentifierNode
      @environment.get(ast_node.name)
      
    when BinaryOpNode
      evaluate_binary_operation(ast_node)
      
    when FunctionCallNode
      evaluate_function_call(ast_node)
      
    when GoalActivationNode
      @goal_engine.activate_goal(ast_node.goal_name, ast_node.args)
      
    when EventEmissionNode
      @event_system.emit(create_event(ast_node))
      
    when LogicQueryNode
      @logic_engine.query(ast_node.query)
      
    when HybridExpressionNode
      evaluate_hybrid_expression(ast_node)
    end
  end
  
  private
  
  def evaluate_hybrid_expression(node)
    # Handle expressions that combine multiple paradigms
    # Example: object.method() triggers goal which emits event
    
    results = []
    
    node.components.each do |component|
      result = evaluate(component)
      results << result
      
      # Handle paradigm transitions
      if component.triggers_goal?
        goal_result = @goal_engine.activate_goal(component.target_goal, [result])
        results << goal_result
      end
      
      if component.emits_event?
        event = create_event_from_result(result, component.event_spec)
        @event_system.emit(event)
      end
    end
    
    # Return final result or composite result
    node.aggregate_results? ? aggregate_results(results) : results.last
  end
  
  def evaluate_function_call(node)
    function = evaluate(node.function)
    args = node.args.map { |arg| evaluate(arg) }
    
    case function
    when PatlangFunction
      function.call(args, self)
    when PatlangGoal
      @goal_engine.activate_goal_with_args(function, args)
    when PatlangClass
      # Constructor call
      function.instantiate(args, self)
    else
      raise RuntimeError.new("Cannot call #{function.class}")
    end
  end
end
```

## Message Queue Architecture

The message passing system extends the existing event architecture to provide thread-safe, persistent, and distributed communication capabilities. The event queue seamlessly transforms into a message queue while maintaining backward compatibility.

### Core Message Queue Components

```ruby
class MessageQueue
  attr_accessor :persistence_layer, :network_layer, :routing_engine, :filtering_engine
  
  def initialize(config = {})
    @config = MessageQueueConfig.new(config)
    @local_queue = ThreadSafeQueue.new(@config.max_queue_size)
    @persistence_layer = create_persistence_layer if @config.persistence_enabled?
    @network_layer = create_network_layer if @config.network_enabled?
    @routing_engine = RoutingEngine.new(@config.routing_rules)
    @filtering_engine = FilteringEngine.new(@config.filters)
    @message_processors = {}
    @subscribers = {}
  end
  
  def send_message(target, message_type, data = {}, options = {})
    message = create_message(target, message_type, data, options)
    
    # Apply filters and routing
    return if @filtering_engine.should_reject?(message)
    transformed_message = @filtering_engine.transform(message)
    
    # Route message based on target and rules
    route_message(transformed_message)
  end
  
  def subscribe(pattern, handler)
    @subscribers[pattern] ||= []
    @subscribers[pattern] << handler
  end
  
  private
  
  def route_message(message)
    routes = @routing_engine.determine_routes(message)
    
    routes.each do |route|
      case route.type
      when :local_queue
        @local_queue.enqueue(message)
      when :persistent_storage
        @persistence_layer.store(message) if @persistence_layer
      when :network_node
        @network_layer.send_to_node(route.destination, message) if @network_layer
      when :cross_thread
        route.destination.message_queue.receive_message(message)
      end
    end
    
    # Process message locally if applicable
    process_local_message(message) if routes.any? { |r| r.type == :local_queue }
  end
  
  def process_local_message(message)
    # Find matching subscribers
    matching_subscribers = find_matching_subscribers(message)
    
    matching_subscribers.each do |subscriber|
      begin
        # Execute subscriber in appropriate context
        execute_subscriber(subscriber, message)
      rescue => error
        handle_subscriber_error(error, subscriber, message)
      end
    end
  end
end

class Message
  attr_accessor :id, :source, :target, :type, :data, :timestamp, :priority, :persistence_required
  
  def initialize(source, target, type, data, options = {})
    @id = options[:id] || generate_message_id
    @source = source
    @target = target
    @type = type
    @data = data
    @timestamp = Time.now
    @priority = options[:priority] || :normal
    @persistence_required = options[:persistence] || false
    @routing_metadata = {}
    @processing_metadata = {}
  end
  
  def serialize
    {
      id: @id,
      source: serialize_endpoint(@source),
      target: serialize_endpoint(@target),
      type: @type,
      data: serialize_data(@data),
      timestamp: @timestamp.to_f,
      priority: @priority,
      persistence_required: @persistence_required,
      routing_metadata: @routing_metadata,
      processing_metadata: @processing_metadata
    }
  end
  
  def self.deserialize(data)
    message = allocate
    message.instance_variable_set(:@id, data[:id])
    message.instance_variable_set(:@source, deserialize_endpoint(data[:source]))
    message.instance_variable_set(:@target, deserialize_endpoint(data[:target]))
    message.instance_variable_set(:@type, data[:type])
    message.instance_variable_set(:@data, deserialize_data(data[:data]))
    message.instance_variable_set(:@timestamp, Time.at(data[:timestamp]))
    message.instance_variable_set(:@priority, data[:priority])
    message.instance_variable_set(:@persistence_required, data[:persistence_required])
    message.instance_variable_set(:@routing_metadata, data[:routing_metadata] || {})
    message.instance_variable_set(:@processing_metadata, data[:processing_metadata] || {})
    message
  end
  
  def cross_thread_boundary?
    @target.is_a?(Thread) && @target != Thread.current
  end
  
  def cross_process_boundary?
    @target.is_a?(String) && @target.include?(':')  # node:port format
  end
end
```

### Thread-Safe Message Queue Implementation

```ruby
class ThreadSafeQueue
  def initialize(max_size = Float::INFINITY)
    @queue = []
    @mutex = Mutex.new
    @condition = ConditionVariable.new
    @max_size = max_size
    @closed = false
  end
  
  def enqueue(message)
    @mutex.synchronize do
      while @queue.size >= @max_size && !@closed
        @condition.wait(@mutex)  # Block until space available
      end
      
      raise QueueClosedError if @closed
      
      # Insert based on priority
      insert_position = find_insert_position(message)
      @queue.insert(insert_position, message)
      
      @condition.signal  # Wake up waiting dequeuers
    end
  end
  
  def dequeue(timeout = nil)
    @mutex.synchronize do
      if timeout
        deadline = Time.now + timeout
        while @queue.empty? && !@closed && Time.now < deadline
          remaining = deadline - Time.now
          @condition.wait(@mutex, remaining)
        end
      else
        while @queue.empty? && !@closed
          @condition.wait(@mutex)
        end
      end
      
      return nil if @queue.empty?
      
      message = @queue.shift
      @condition.signal  # Wake up waiting enqueuers
      message
    end
  end
  
  def close
    @mutex.synchronize do
      @closed = true
      @condition.broadcast  # Wake up all waiting threads
    end
  end
  
  private
  
  def find_insert_position(message)
    # Insert based on priority (urgent, high, normal, low)
    priority_order = { urgent: 0, high: 1, normal: 2, low: 3 }
    message_priority = priority_order[message.priority] || 2
    
    @queue.each_with_index do |queued_message, index|
      queued_priority = priority_order[queued_message.priority] || 2
      return index if message_priority < queued_priority
    end
    
    @queue.size  # Insert at end if no higher priority found
  end
end

class MessageProcessor
  def initialize(thread_pool_size = 4)
    @thread_pool = ThreadPool.new(thread_pool_size)
    @processing_stats = ProcessingStats.new
  end
  
  def process_message(message, subscriber)
    @thread_pool.submit do
      start_time = Time.now
      
      begin
        result = subscriber.call(message)
        execution_time = Time.now - start_time
        
        @processing_stats.record_success(message, execution_time)
        result
        
      rescue => error
        execution_time = Time.now - start_time
        @processing_stats.record_error(message, error, execution_time)
        
        # Re-raise for error handling
        raise error
      end
    end
  end
end
```

### Persistence Layer Architecture

```ruby
class MessagePersistenceLayer
  def initialize(config)
    @config = config
    @storage_backend = create_storage_backend(config.storage_type)
    @compression = CompressionEngine.new(config.compression_algorithm)
    @retention_manager = RetentionManager.new(config.retention_policy)
    @indexing_engine = IndexingEngine.new
  end
  
  def store(message)
    return unless should_persist?(message)
    
    # Serialize and compress message
    serialized_data = message.serialize
    compressed_data = @compression.compress(serialized_data)
    
    # Create storage record
    record = StorageRecord.new(
      message_id: message.id,
      timestamp: message.timestamp,
      data: compressed_data,
      size: compressed_data.bytesize,
      type: message.type,
      source: message.source.to_s,
      target: message.target.to_s
    )
    
    # Store with indexing
    @storage_backend.store(record)
    @indexing_engine.index(record)
    
    # Schedule for retention management
    @retention_manager.schedule_for_cleanup(record)
  end
  
  def retrieve_messages(criteria)
    # Use indexes for efficient retrieval
    record_ids = @indexing_engine.search(criteria)
    records = @storage_backend.retrieve_batch(record_ids)
    
    # Decompress and deserialize
    records.map do |record|
      decompressed_data = @compression.decompress(record.data)
      Message.deserialize(decompressed_data)
    end
  end
  
  def replay_from_checkpoint(checkpoint_id)
    checkpoint_message = find_checkpoint_message(checkpoint_id)
    return nil unless checkpoint_message
    
    # Get all messages after checkpoint
    criteria = {
      timestamp_after: checkpoint_message.timestamp,
      exclude_patterns: ['debug:*', 'metrics:*']  # Don't replay ephemeral messages
    }
    
    messages = retrieve_messages(criteria)
    
    # Sort by timestamp for correct replay order
    messages.sort_by(&:timestamp)
  end
  
  private
  
  def should_persist?(message)
    # Check persistence patterns
    patterns = @config.persist_patterns
    exclude_patterns = @config.exclude_patterns
    
    # Include if matches persist patterns
    include_match = patterns.any? { |pattern| message_matches_pattern?(message, pattern) }
    
    # Exclude if matches exclude patterns
    exclude_match = exclude_patterns.any? { |pattern| message_matches_pattern?(message, pattern) }
    
    # Persist if explicitly required or matches patterns and not excluded
    message.persistence_required || (include_match && !exclude_match)
  end
  
  def message_matches_pattern?(message, pattern)
    # Support wildcard patterns like "business:*" or "state:checkpoint"
    if pattern.end_with?('*')
      prefix = pattern[0...-1]
      message.type.start_with?(prefix)
    else
      message.type == pattern
    end
  end
end

class StorageBackend
  # Abstract base class for different storage implementations
  def store(record)
    raise NotImplementedError
  end
  
  def retrieve(record_id)
    raise NotImplementedError
  end
  
  def retrieve_batch(record_ids)
    raise NotImplementedError
  end
end

class SQLiteStorageBackend < StorageBackend
  def initialize(db_path)
    @db = SQLite3::Database.new(db_path)
    create_tables
  end
  
  def store(record)
    @db.execute(
      "INSERT INTO messages (id, timestamp, data, size, type, source, target) VALUES (?, ?, ?, ?, ?, ?, ?)",
      record.message_id, record.timestamp.to_f, record.data, record.size, record.type, record.source, record.target
    )
  end
  
  def retrieve(record_id)
    row = @db.get_first_row("SELECT * FROM messages WHERE id = ?", record_id)
    return nil unless row
    
    StorageRecord.from_database_row(row)
  end
  
  def retrieve_batch(record_ids)
    placeholders = (['?'] * record_ids.size).join(',')
    rows = @db.execute("SELECT * FROM messages WHERE id IN (#{placeholders})", *record_ids)
    
    rows.map { |row| StorageRecord.from_database_row(row) }
  end
  
  private
  
  def create_tables
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        timestamp REAL NOT NULL,
        data BLOB NOT NULL,
        size INTEGER NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        target TEXT NOT NULL,
        created_at REAL DEFAULT (julianday('now'))
      )
    SQL
    
    # Create indexes for efficient querying
    @db.execute "CREATE INDEX IF NOT EXISTS idx_timestamp ON messages (timestamp)"
    @db.execute "CREATE INDEX IF NOT EXISTS idx_type ON messages (type)"
    @db.execute "CREATE INDEX IF NOT EXISTS idx_source ON messages (source)"
    @db.execute "CREATE INDEX IF NOT EXISTS idx_target ON messages (target)"
  end
end
```

### Network Layer for Distributed Queues

```ruby
class NetworkLayer
  def initialize(config)
    @config = config
    @local_node_id = config.node_id
    @cluster_nodes = config.cluster_nodes
    @connection_pool = ConnectionPool.new
    @heartbeat_manager = HeartbeatManager.new(config.heartbeat_interval)
    @message_serializer = NetworkMessageSerializer.new
  end
  
  def send_to_node(node_id, message)
    connection = @connection_pool.get_connection(node_id)
    
    # Serialize message for network transport
    network_message = NetworkMessage.new(
      source_node: @local_node_id,
      target_node: node_id,
      payload: message.serialize,
      message_id: message.id,
      timestamp: Time.now
    )
    
    serialized_data = @message_serializer.serialize(network_message)
    
    begin
      connection.send(serialized_data)
      
      # Wait for acknowledgment
      ack = connection.receive_ack(timeout: 5.0)
      handle_send_result(message, ack)
      
    rescue NetworkError => error
      handle_network_error(message, node_id, error)
    ensure
      @connection_pool.return_connection(node_id, connection)
    end
  end
  
  def start_network_listener
    @listener_thread = Thread.new do
      server = TCPServer.new(@config.listen_port)
      
      while true
        client = server.accept
        handle_incoming_connection(client)
      end
    end
  end
  
  private
  
  def handle_incoming_connection(client)
    Thread.new do
      begin
        while data = client.gets
          network_message = @message_serializer.deserialize(data)
          
          # Send acknowledgment
          client.puts("ACK:#{network_message.message_id}")
          
          # Process received message
          process_network_message(network_message)
        end
      rescue => error
        log_network_error(error, client)
      ensure
        client.close
      end
    end
  end
  
  def process_network_message(network_message)
    # Deserialize the original message
    original_message = Message.deserialize(network_message.payload)
    
    # Route to local message queue
    local_message_queue = MessageQueue.current
    local_message_queue.receive_external_message(original_message)
  end
end

class ConnectionPool
  def initialize
    @connections = {}
    @mutex = Mutex.new
  end
  
  def get_connection(node_id)
    @mutex.synchronize do
      @connections[node_id] ||= create_connection(node_id)
    end
  end
  
  def return_connection(node_id, connection)
    # For now, keep connections open
    # In production, implement connection pooling
  end
  
  private
  
  def create_connection(node_id)
    host, port = parse_node_address(node_id)
    TCPSocket.new(host, port)
  rescue => error
    raise NetworkError.new("Failed to connect to #{node_id}: #{error.message}")
  end
  
  def parse_node_address(node_id)
    parts = node_id.split(':')
    [parts[0], parts[1].to_i]
  end
end
```

### Cross-Thread Communication Design

```ruby
class ThreadManager
  def initialize
    @threads = {}
    @thread_message_queues = {}
    @thread_registry = ThreadRegistry.new
  end
  
  def create_thread(name = nil, &block)
    thread = Thread.new do
      # Set up thread-local message queue
      thread_queue = MessageQueue.new
      Thread.current[:message_queue] = thread_queue
      Thread.current[:thread_name] = name || "thread_#{Thread.current.object_id}"
      
      # Register thread
      @thread_registry.register(Thread.current)
      
      begin
        # Execute thread block
        block.call
      ensure
        # Clean up on thread exit
        @thread_registry.unregister(Thread.current)
        thread_queue.close
      end
    end
    
    # Store thread reference
    @threads[name] = thread if name
    @thread_message_queues[thread] = thread[:message_queue]
    
    thread
  end
  
  def send_message_to_thread(target_thread, message_type, data = {})
    target_queue = @thread_message_queues[target_thread]
    raise ThreadNotFoundError.new("Thread not found or not message-enabled") unless target_queue
    
    message = Message.new(
      source: Thread.current,
      target: target_thread,
      type: message_type,
      data: data
    )
    
    target_queue.enqueue(message)
  end
  
  def get_thread_by_name(name)
    @threads[name]
  end
  
  def broadcast_message(message_type, data = {}, filter = nil)
    @thread_message_queues.each do |thread, queue|
      next if thread == Thread.current  # Don't send to self
      next if filter && !filter.call(thread)
      
      message = Message.new(
        source: Thread.current,
        target: thread,
        type: message_type,
        data: data
      )
      
      queue.enqueue(message)
    end
  end
end

class ThreadRegistry
  def initialize
    @registered_threads = {}
    @mutex = Mutex.new
  end
  
  def register(thread)
    @mutex.synchronize do
      @registered_threads[thread.object_id] = {
        thread: thread,
        name: thread[:thread_name],
        created_at: Time.now,
        message_queue: thread[:message_queue]
      }
    end
  end
  
  def unregister(thread)
    @mutex.synchronize do
      @registered_threads.delete(thread.object_id)
    end
  end
  
  def find_by_name(name)
    @mutex.synchronize do
      entry = @registered_threads.values.find { |entry| entry[:name] == name }
      entry&.[](:thread)
    end
  end
  
  def all_threads
    @mutex.synchronize do
      @registered_threads.values.map { |entry| entry[:thread] }
    end
  end
end
```

### Integration with Existing Event System

```ruby
class EventSystemIntegration
  def initialize(event_system, message_queue)
    @event_system = event_system
    @message_queue = message_queue
    @integration_rules = []
  end
  
  def setup_integration
    # Events automatically become messages when crossing boundaries
    @event_system.add_global_event_interceptor do |event, context|
      if should_convert_to_message?(event, context)
        convert_event_to_message(event, context)
      end
    end
    
    # Messages can trigger local events
    @message_queue.subscribe("event:*") do |message|
      event_type = message.type.sub(/^event:/, '')
      @event_system.emit_event(event_type, message.data)
    end
  end
  
  def add_integration_rule(rule)
    @integration_rules << rule
  end
  
  private
  
  def should_convert_to_message?(event, context)
    # Convert to message if:
    # 1. Event has cross-thread targets
    # 2. Event has network targets
    # 3. Event requires persistence
    # 4. Custom integration rules match
    
    has_cross_thread_targets?(event) ||
    has_network_targets?(event) ||
    requires_persistence?(event) ||
    custom_rules_match?(event, context)
  end
  
  def convert_event_to_message(event, context)
    # Determine targets from event context
    targets = extract_targets_from_event(event, context)
    
    targets.each do |target|
      message_type = "event:#{event.type}"
      @message_queue.send_message(target, message_type, event.data)
    end
  end
  
  def has_cross_thread_targets?(event)
    # Check if event targets include other threads
    event.targets&.any? { |target| target.is_a?(Thread) && target != Thread.current }
  end
  
  def has_network_targets?(event)
    # Check if event targets include network nodes
    event.targets&.any? { |target| target.is_a?(String) && target.include?(':') }
  end
  
  def requires_persistence?(event)
    # Check if event should be persisted
    event.metadata[:persist] == true ||
    event.type.start_with?('state:', 'business:', 'audit:')
  end
end
```

---

## AST Node Hierarchy

```ruby
# Base AST node with type annotation support
class ASTNode
  attr_accessor :type_annotation, :line, :column, :paradigm_context
  
  def initialize(line = nil, column = nil)
    @line = line
    @column = column
    @paradigm_context = []  # Tracks which paradigms this node uses
  end
  
  def accept(visitor)
    visitor.visit(self)
  end
  
  def uses_paradigm?(paradigm)
    @paradigm_context.include?(paradigm)
  end
end

# Expression nodes
class ExpressionNode < ASTNode
  def evaluate_in_context(context)
    context.evaluate(self)
  end
end

class LiteralNode < ExpressionNode
  attr_reader :value, :literal_type
  
  def initialize(value, literal_type, line = nil, column = nil)
    super(line, column)
    @value = value
    @literal_type = literal_type
  end
end

class IdentifierNode < ExpressionNode
  attr_reader :name
  
  def initialize(name, line = nil, column = nil)
    super(line, column)
    @name = name
  end
end

class BinaryOpNode < ExpressionNode
  attr_reader :left, :operator, :right
  
  def initialize(left, operator, right, line = nil, column = nil)
    super(line, column)
    @left = left
    @operator = operator
    @right = right
  end
end

class FunctionCallNode < ExpressionNode
  attr_reader :function, :args
  
  def initialize(function, args, line = nil, column = nil)
    super(line, column)
    @function = function
    @args = args
    @paradigm_context << :functional
  end
end

# Statement nodes
class StatementNode < ASTNode
  def execute_in_context(context)
    context.evaluate(self)
  end
end

class AssignmentNode < StatementNode
  attr_reader :target, :value
  
  def initialize(target, value, line = nil, column = nil)
    super(line, column)
    @target = target
    @value = value
  end
end

class FunctionNode < StatementNode
  attr_reader :name, :parameters, :body, :return_type, :contracts
  
  def initialize(name:, parameters: [], body:, return_type: nil, contracts: [])
    super()
    @name = name
    @parameters = parameters
    @body = body
    @return_type = return_type
    @contracts = contracts
    @paradigm_context << :functional
    @paradigm_context << :oop if contracts.any?
  end
end

class ClassNode < StatementNode
  attr_reader :name, :superclass, :fields, :methods, :invariants
  
  def initialize(name:, superclass: nil, fields: [], methods: [], invariants: [])
    super()
    @name = name
    @superclass = superclass
    @fields = fields
    @methods = methods
    @invariants = invariants
    @paradigm_context << :oop
  end
end

# Goal-oriented programming nodes
class GoalNode < StatementNode
  attr_reader :name, :requirements, :conditions, :actions
  
  def initialize(name:, requirements: [], conditions: [], actions: [])
    super()
    @name = name
    @requirements = requirements
    @conditions = conditions
    @actions = actions
    @paradigm_context << :goal_oriented
  end
end

class GoalActivationNode < ExpressionNode
  attr_reader :goal_name, :args
  
  def initialize(goal_name, args = [])
    super()
    @goal_name = goal_name
    @args = args
    @paradigm_context << :goal_oriented
  end
end

# Event-driven programming nodes
class EventHandlerNode < StatementNode
  attr_reader :event_spec, :body
  
  def initialize(event_spec, body)
    super()
    @event_spec = event_spec
    @body = body
    @paradigm_context << :event_driven
  end
end

class EventEmissionNode < StatementNode
  attr_reader :event_name, :event_data
  
  def initialize(event_name, event_data = nil)
    super()
    @event_name = event_name
    @event_data = event_data
    @paradigm_context << :event_driven
  end
end

# Logic programming nodes
class LogicFactNode < StatementNode
  attr_reader :predicate, :args
  
  def initialize(predicate, args = [])
    super()
    @predicate = predicate
    @args = args
    @paradigm_context << :logic
  end
end

class LogicRuleNode < StatementNode
  attr_reader :head, :body
  
  def initialize(head, body)
    super()
    @head = head
    @body = body
    @paradigm_context << :logic
  end
end

class LogicQueryNode < ExpressionNode
  attr_reader :query
  
  def initialize(query)
    super()
    @query = query
    @paradigm_context << :logic
  end
end

# Multi-paradigm nodes
class HybridExpressionNode < ExpressionNode
  attr_reader :components, :paradigm_transitions
  
  def initialize(components, paradigm_transitions = [])
    super()
    @components = components
    @paradigm_transitions = paradigm_transitions
    
    # Determine all paradigms used
    components.each do |component|
      @paradigm_context.concat(component.paradigm_context)
    end
    @paradigm_context.uniq!
  end
  
  def aggregate_results?
    @paradigm_transitions.any? { |t| t[:type] == :aggregate }
  end
  
  def triggers_goal?
    @paradigm_transitions.any? { |t| t[:type] == :goal_activation }
  end
  
  def emits_event?
    @paradigm_transitions.any? { |t| t[:type] == :event_emission }
  end
end
```

## Type System Design

The type system uses Hindley-Milner inference extended to handle multi-paradigm constructs.

```ruby
class TypeSystem
  def initialize
    @type_environment = TypeEnvironment.new
    @constraints = []
    @substitutions = {}
    @fresh_var_counter = 0
  end
  
  def infer_type(ast_node, environment = @type_environment)
    case ast_node
    when LiteralNode
      infer_literal_type(ast_node)
    when IdentifierNode
      infer_identifier_type(ast_node, environment)
    when FunctionNode
      infer_function_type(ast_node, environment)
    when GoalNode
      infer_goal_type(ast_node, environment)
    when EventHandlerNode
      infer_event_handler_type(ast_node, environment)
    when HybridExpressionNode
      infer_hybrid_type(ast_node, environment)
    end
  end
  
  private
  
  def infer_function_type(node, env)
    # Create fresh type variables for parameters
    param_types = node.parameters.map { fresh_type_variable }
    return_type = fresh_type_variable
    
    # Create function environment
    func_env = env.extend
    node.parameters.zip(param_types).each do |param, type|
      func_env.bind(param.name, type)
    end
    
    # Infer body type
    body_type = infer_type(node.body, func_env)
    
    # Add constraint: body type must match return type
    add_constraint(body_type, return_type)
    
    # Handle contracts (pre/post conditions)
    if node.contracts.any?
      infer_contract_types(node.contracts, func_env, param_types, return_type)
    end
    
    FunctionType.new(param_types, return_type)
  end
  
  def infer_goal_type(node, env)
    # Goals have special type structure
    requirement_types = node.requirements.map { |req| infer_type(req, env) }
    condition_types = node.conditions.map { |cond| infer_type(cond, env) }
    action_types = node.actions.map { |action| infer_type(action, env) }
    
    # All conditions must be boolean
    condition_types.each do |cond_type|
      add_constraint(cond_type, BooleanType.new)
    end
    
    # Actions determine goal result type
    result_type = action_types.empty? ? UnitType.new : action_types.last
    
    GoalType.new(requirement_types, condition_types, result_type)
  end
  
  def infer_hybrid_type(node, env)
    # Multi-paradigm expressions require special handling
    component_types = node.components.map { |comp| infer_type(comp, env) }
    
    # Handle paradigm transitions
    result_type = component_types.first
    
    node.paradigm_transitions.each do |transition|
      case transition[:type]
      when :goal_activation
        # Result type becomes goal result type
        goal_type = env.lookup(transition[:goal_name])
        result_type = goal_type.result_type if goal_type.is_a?(GoalType)
        
      when :event_emission
        # Events don't change result type but may add side effects
        # Type system tracks effect types
        add_effect_constraint(result_type, EventEffectType.new(transition[:event_name]))
        
      when :function_composition
        # Function composition: f(g(x)) where g's output feeds f's input
        add_constraint(component_types[transition[:from]], 
                      get_function_input_type(component_types[transition[:to]]))
      end
    end
    
    result_type
  end
  
  def solve_constraints
    unifier = Unifier.new
    @constraints.each do |constraint|
      unifier.unify(constraint.left_type, constraint.right_type)
    end
    @substitutions = unifier.substitutions
  end
  
  def fresh_type_variable
    var = TypeVariable.new("T#{@fresh_var_counter}")
    @fresh_var_counter += 1
    var
  end
end

# Type definitions
class Type
  def substitute(substitutions)
    self
  end
end

class PrimitiveType < Type
  attr_reader :name
  
  def initialize(name)
    @name = name
  end
  
  def ==(other)
    other.is_a?(PrimitiveType) && @name == other.name
  end
end

class FunctionType < Type
  attr_reader :parameter_types, :return_type
  
  def initialize(parameter_types, return_type)
    @parameter_types = parameter_types
    @return_type = return_type
  end
  
  def substitute(substitutions)
    new_param_types = @parameter_types.map { |pt| pt.substitute(substitutions) }
    new_return_type = @return_type.substitute(substitutions)
    FunctionType.new(new_param_types, new_return_type)
  end
end

class GoalType < Type
  attr_reader :requirement_types, :condition_types, :result_type
  
  def initialize(requirement_types, condition_types, result_type)
    @requirement_types = requirement_types
    @condition_types = condition_types
    @result_type = result_type
  end
end

class EventType < Type
  attr_reader :event_name, :data_type
  
  def initialize(event_name, data_type = nil)
    @event_name = event_name
    @data_type = data_type
  end
end

class TypeVariable < Type
  attr_reader :name
  
  def initialize(name)
    @name = name
  end
  
  def substitute(substitutions)
    substitutions[@name] || self
  end
end

# Built-in types
class NumberType < PrimitiveType
  def initialize
    super('Number')
  end
end

class StringType < PrimitiveType
  def initialize
    super('String')
  end
end

class BooleanType < PrimitiveType
  def initialize
    super('Boolean')
  end
end

class UnitType < PrimitiveType
  def initialize
    super('Unit')
  end
end
```

## Memory Management Strategy

Ruby's garbage collector handles most memory management, but we implement additional strategies for Patlang-specific concerns.

```ruby
class MemoryManager
  def initialize
    @object_pool = ObjectPool.new
    @reference_tracker = ReferenceTracker.new
    @scope_stack = []
  end
  
  # Object lifecycle management
  def allocate_object(type, initial_data = {})
    object = @object_pool.acquire(type) || create_new_object(type)
    object.initialize_with_data(initial_data)
    @reference_tracker.track(object)
    object
  end
  
  def deallocate_object(object)
    @reference_tracker.untrack(object)
    object.cleanup if object.respond_to?(:cleanup)
    @object_pool.release(object)
  end
  
  # Scope-based memory management
  def enter_scope
    scope = MemoryScope.new
    @scope_stack.push(scope)
    scope
  end
  
  def exit_scope
    scope = @scope_stack.pop
    scope.cleanup_objects
    scope
  end
  
  # Goal-specific memory management
  def allocate_goal_context(goal)
    context = GoalContext.new(goal)
    context.memory_scope = enter_scope
    context
  end
  
  def cleanup_goal_context(context)
    exit_scope
    context.cleanup
  end
  
  private
  
  def create_new_object(type)
    case type
    when :patlang_object
      PatlangObject.new
    when :patlang_function
      PatlangFunction.new
    when :patlang_goal
      PatlangGoal.new
    when :patlang_event
      PatlangEvent.new
    else
      raise "Unknown object type: #{type}"
    end
  end
end

class ObjectPool
  def initialize
    @pools = Hash.new { |h, k| h[k] = [] }
    @max_pool_size = 100
  end
  
  def acquire(type)
    pool = @pools[type]
    pool.empty? ? nil : pool.pop
  end
  
  def release(object)
    type = object.class.name.downcase.to_sym
    pool = @pools[type]
    
    if pool.size < @max_pool_size
      object.reset_for_reuse if object.respond_to?(:reset_for_reuse)
      pool.push(object)
    end
  end
end

class MemoryScope
  def initialize
    @allocated_objects = []
    @cleanup_callbacks = []
  end
  
  def add_object(object)
    @allocated_objects << object
  end
  
  def add_cleanup_callback(&block)
    @cleanup_callbacks << block
  end
  
  def cleanup_objects
    @cleanup_callbacks.each(&:call)
    @allocated_objects.each(&:cleanup) if @allocated_objects.respond_to?(:cleanup)
    @allocated_objects.clear
    @cleanup_callbacks.clear
  end
end
```

## Implementation Roadmap

### Phase 1: Core Infrastructure (Weeks 1-4)

#### Week 1: Lexical Analysis
- **Goal**: Complete lexer implementation
- **Deliverables**:
  - Token definitions for all Patlang constructs
  - Multi-word operator handling ("is not", "becomes")
  - Natural language keyword recognition
  - Comment and whitespace handling
- **Success Criteria**: Lexer can tokenize all syntax examples from [`syntax.md`](syntax.md)

#### Week 2: Parsing Foundation
- **Goal**: Basic recursive descent parser
- **Deliverables**:
  - Expression parsing with operator precedence
  - Statement parsing (assignments, declarations)
  - Block structure parsing (`{}` vs `begin...end`)
- **Success Criteria**: Parser can handle basic Patlang programs

#### Week 3: AST Construction
- **Goal**: Complete AST node hierarchy
- **Deliverables**:
  - All AST node classes with proper inheritance
  - Visitor pattern implementation
  - AST pretty-printing for debugging
- **Success Criteria**: Parser produces valid AST for complex programs

#### Week 4: Basic Interpreter
- **Goal**: Tree-walking interpreter for expressions
- **Deliverables**:
  - Basic expression evaluation
  - Variable assignment and lookup
  - Arithmetic and logical operations
- **Success Criteria**: Can evaluate basic mathematical expressions

### Phase 2: Object-Oriented Foundation (Weeks 5-8)

#### Week 5: Object System
- **Goal**: Basic OOP implementation
- **Deliverables**:
  - PatlangObject base class
  - Property access and modification
  - Method definition and calling
- **Success Criteria**: Can create objects and call methods

#### Week 6: Class System
- **Goal**: Class definitions and inheritance
- **Deliverables**:
  - Class parsing and instantiation
  - Method resolution and dispatch
  - Basic inheritance support
- **Success Criteria**: Can define and instantiate classes

#### Week 7: Advanced OOP Features
- **Goal**: Complete OOP feature set
- **Deliverables**:
  - Constructor methods
  - Access control (private/public concepts)
  - Method overriding
- **Success Criteria**: Can implement complex OOP patterns

#### Week 8: Environment Management
- **Goal**: Proper scope and environment handling
- **Deliverables**:
  - Lexical scoping implementation
  - Environment chain management
  - Variable resolution rules
- **Success Criteria**: Proper variable scoping in all contexts

### Phase 3: Control Flow and Functions (Weeks 9-12)

#### Week 9: Control Structures
- **Goal**: If statements, loops, and branching
- **Deliverables**:
  - If/then/else/elsif parsing and execution
  - While and for loop implementation
  - Break/continue support
- **Success Criteria**: Can execute complex control flow

#### Week 10: Function System
- **Goal**: Function definitions and calls
- **Deliverables**:
  - Function parsing with parameter lists
  - Function call execution with argument binding
  - Return value handling
- **Success Criteria**: Can define and call functions with parameters

#### Week 11: Closures and Blocks
- **Goal**: First-class functions and closures
- **Deliverables**:
  - Closure creation and environment capture
  - Block syntax parsing (`|x| x * 2`)
  - Higher-order function support
- **Success Criteria**: Can pass functions as arguments

#### Week 12: Error Handling
- **Goal**: Exception system
- **Deliverables**:
  - Try/catch/finally implementation
  - Exception types and throwing
  - Stack trace generation
- **Success Criteria**: Robust error handling and reporting

### Phase 4: Multi-Paradigm Features (Weeks 13-18)

#### Week 13-14: Goal-Oriented Programming
- **Goal**: Goal system implementation
- **Deliverables**:
  - Goal definition parsing and storage
  - Dependency graph construction
  - Goal activation and achievement checking
- **Success Criteria**: Can execute goal-oriented programs like email example

#### Week 15: Event System
- **Goal**: Event-driven programming
- **Deliverables**:
  - Event definition and emission
  - Event handler registration and execution
  - Event queue management
- **Success Criteria**: Can handle events and triggers

#### Week 16: Logic Programming Basics
- **Goal**: Basic logic engine
- **Deliverables**:
  - Fact assertion and storage
  - Simple rule definition
  - Basic query processing
- **Success Criteria**: Can execute simple logic programs

#### Week 17: Type Inference Engine
- **Goal**: Basic type inference
- **Deliverables**:
  - Hindley-Milner implementation
  - Constraint generation and solving
  - Type error reporting
- **Success Criteria**: Can infer types for most programs

#### Week 18: Integration and Testing
- **Goal**: Multi-paradigm integration
- **Deliverables**:
  - Cross-paradigm interaction testing
  - Performance optimization
  - Comprehensive test suite
- **Success Criteria**: All paradigms work together seamlessly

### Phase 5: Advanced Features and REPL (Weeks 19-22)

#### Week 19-20: REPL Implementation
- **Goal**: Interactive development environment
- **Deliverables**:
  - Read-eval-print loop
  - Multi-line input handling
  - History and editing support
- **Success Criteria**: Fully functional interactive environment

#### Week 21: Standard Library
- **Goal**: Core built-in functions and types
- **Deliverables**:
  - String manipulation functions
  - Array/list operations
  - Math functions
  - I/O operations
- **Success Criteria**: Rich standard library for real programs

#### Week 22: Self-Hosting Preparation
- **Goal**: Bootstrap compiler preparation
- **Deliverables**:
  - Compiler API design
  - Self-compilation testing framework
  - Performance benchmarking
- **Success Criteria**: Ready for self-hosting transition

## Ruby Implementation Strategies

### 1. Pure Ruby Standard Library Approach
- **No external dependencies**: Use only Ruby's built-in classes and modules
- **Modular design**: Each component in separate Ruby files
- **Clean interfaces**: Well-defined APIs between components

### 2. Object-Oriented Design Patterns
```ruby
# Visitor pattern for AST traversal
class ASTVisitor
  def visit(node)
    method_name = "visit_#{node.class.name.downcase}"
    if respond_to?(method_name)
      send(method_name, node)
    else
      visit_default(node)
    end
  end
  
  def visit_default(node)
    # Default behavior for unknown nodes
  end
end

# Strategy pattern for evaluation
class EvaluationStrategy
  def evaluate(node, context)
    raise NotImplementedError
  end
end

class OOPEvaluationStrategy < EvaluationStrategy
  def evaluate(node, context)
    # OOP-specific evaluation logic
  end
end

class GoalEvaluationStrategy < EvaluationStrategy
  def evaluate(node, context)
    # Goal-oriented evaluation logic
  end
end
```

### 3. Ruby Metaprogramming (Minimal Usage)
```ruby
# Dynamic method dispatch for built-in functions
class BuiltinFunctions
  def self.define_builtin(name, &block)
    define_method("builtin_#{name}", &block)
  end
  
  define_builtin :print do |args, context|
    args.each { |arg| puts arg.to_string }
    NilObject.new
  end
  
  define_builtin :length do |args, context|
    obj = args.first
    NumberObject.new(obj.respond_to?(:length) ? obj.length : 0)
  end
end
```

### 4. Module-Based Architecture
```ruby
module Lexical
  class Lexer
    # Lexer implementation
  end
  
  class Token
    # Token implementation
  end
end

module Parsing
  class Parser
    # Parser implementation
  end
  
  module AST
    class Node
      # Base AST node
    end
  end
end

module Runtime
  class Interpreter
    # Interpreter implementation
  end
  
  class Environment
    # Environment implementation
  end
end
```

### 5. Fiber-Based Concurrency
```ruby
# Event loop using Ruby Fibers
class EventLoop
  def initialize
    @event_queue = []
    @running = false
    @main_fiber = nil
  end
  
  def run
    @running = true
    @main_fiber = Fiber.current
    
    while @running && !@event_queue.empty?
      event = @event_queue.shift
      process_event(event)
    end
  end
  
  def schedule_event(event)
    @event_queue << event
    yield_to_main if Fiber.current != @main_fiber
  end
  
  private
  
  def process_event(event)
    fiber = Fiber.new do
      event.handler.call(event)
    end
    
    fiber.resume
  end
  
  def yield_to_main
    @main_fiber.resume if @main_fiber
  end
end
```

## Performance Considerations

### 1. Interpreter Optimization Strategies
- **Bytecode compilation**: Future phase for performance improvement
- **AST caching**: Cache parsed ASTs for frequently executed code
- **Method caching**: Cache method lookups and dispatch
- **Type specialization**: Optimize for common type patterns

### 2. Memory Management Optimization
- **Object pooling**: Reuse objects to reduce GC pressure
- **Scope-based allocation**: Group related objects for efficient cleanup
- **Lazy evaluation**: Defer computation until results are needed

### 3. Goal Engine Optimization
- **Dependency caching**: Cache dependency graph analysis
- **Incremental updates**: Only recompute affected goals
- **Parallel goal execution**: Execute independent goals concurrently

### 4. Event System Optimization
- **Event pooling**: Reuse event objects
- **Handler prioritization**: Execute high-priority handlers first
- **Batch processing**: Group related events for efficient processing

## Integration Points for Advanced Features

### 1. Type Inference Integration
- **Cross-paradigm types**: Types that span multiple paradigms
- **Effect tracking**: Track side effects in type system
- **Constraint propagation**: Propagate type constraints across paradigm boundaries

### 2. Async I/O Integration
- **Fiber-based async**: Use Ruby Fibers for cooperative multitasking
- **Event-driven I/O**: Integrate with event system for non-blocking operations
- **Goal-triggered I/O**: I/O operations as goal dependencies

### 3. Logic Programming Integration
- **Fact-based types**: Use logic facts to inform type inference
- **Rule-based optimization**: Use logic rules for code optimization
- **Query-driven execution**: Execute code based on logic queries

### 4. Contract Programming Integration
- **Design by contract**: Pre/post conditions and invariants
- **Runtime verification**: Check contracts during execution
- **Static analysis**: Analyze contracts at compile time

### 5. REPL Integration Points
- **Live code reloading**: Update running programs without restart
- **Interactive debugging**: Step through execution interactively
- **Multi-paradigm exploration**: Switch between paradigms in REPL
- **Visualization support**: Display object graphs, goal dependencies, event flows

---

This architecture provides a solid foundation for implementing the Patlang interpreter in Ruby, with clear separation of concerns, multi-paradigm integration, and a path toward self-hosting. The modular design allows for incremental implementation while maintaining the flexibility needed for Patlang's innovative language features.