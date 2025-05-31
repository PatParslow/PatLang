# Patlang Test Categories

## Overview

This document defines the different categories of tests for the Patlang interpreter, organized by scope and purpose.

## 1. Unit Tests for Interpreter Components

### Lexer/Tokenizer Tests

Tests for the lexical analysis phase that converts source code into tokens.

```ruby
# Example test structure (implementation will be in Ruby)
class LexerTests
  def test_natural_language_operators
    # Test "is", "becomes", "is not", etc.
    tokens = lexer.tokenize("user is not admin")
    assert_token_sequence(tokens, [:IDENTIFIER, :IS_NOT, :IDENTIFIER])
  end
  
  def test_multi_word_keywords
    # Test "make a", "called", etc.
    tokens = lexer.tokenize("make a function called test")
    assert_token_sequence(tokens, [:MAKE, :A, :FUNCTION, :CALLED, :IDENTIFIER])
  end
  
  def test_block_delimiters
    # Test both {} and begin...end styles
    tokens_brace = lexer.tokenize("{ code }")
    tokens_begin = lexer.tokenize("begin code end")
    assert_equivalent_block_tokens(tokens_brace, tokens_begin)
  end
  
  def test_string_literals
    # Test various string formats
    assert_token_value('"hello"', "hello")
    assert_token_value("'world'", "world")
    assert_token_value('"""multi\nline"""', "multi\nline")
  end
  
  def test_number_literals
    # Test integer and float parsing
    assert_token_value("42", 42)
    assert_token_value("3.14", 3.14)
    assert_token_value("1.23e-4", 1.23e-4)
  end
  
  def test_comment_handling
    # Test comment parsing and removal
    code_with_comments = """
      # Single line comment
      x = 42 /* inline comment */ + 1
      /* Multi-line
         comment */
      y = x
    """
    tokens = lexer.tokenize(code_with_comments)
    # Comments should be filtered out
    assert_no_comment_tokens(tokens)
  end
end
```

### Parser Tests

Tests for the parsing phase that builds Abstract Syntax Trees from tokens.

```ruby
class ParserTests
  def test_make_declarations
    # Test all declaration types
    ast = parser.parse("make a function called test { }")
    assert_instance_of(FunctionNode, ast.statements[0])
    
    ast = parser.parse("make a goal called process_data { }")
    assert_instance_of(GoalNode, ast.statements[0])
    
    ast = parser.parse("make a template called User { }")
    assert_instance_of(ClassNode, ast.statements[0])
  end
  
  def test_expression_precedence
    # Test operator precedence according to specification
    test_cases = [
      { input: "a + b * c", expected: "(a + (b * c))" },
      { input: "a * b + c", expected: "((a * b) + c)" },
      { input: "a ** b ** c", expected: "(a ** (b ** c))" }, # Right associative
      { input: "not a and b", expected: "((not a) and b)" }
    ]
    
    test_cases.each do |test_case|
      ast = parser.parse(test_case[:input])
      assert_ast_structure(ast, test_case[:expected])
    end
  end
  
  def test_natural_language_syntax
    # Test English-like constructs
    constructs = [
      "when user: login is activated { print 'Welcome' }",
      "if user is logged in then show_dashboard() end",
      "while count is less than 10 do increment_count() end",
      "for each item in list: process_item(item) end"
    ]
    
    constructs.each do |construct|
      ast = parser.parse(construct)
      assert_valid_ast(ast)
    end
  end
  
  def test_block_parsing
    # Test both brace and begin...end styles
    brace_style = "if true { print 'yes' } else { print 'no' }"
    begin_end_style = "if true begin print 'yes' end else begin print 'no' end"
    
    ast1 = parser.parse(brace_style)
    ast2 = parser.parse(begin_end_style)
    
    assert_equivalent_asts(ast1, ast2)
  end
end
```

### AST Node Tests

Tests for Abstract Syntax Tree node behavior and structure.

```ruby
class ASTNodeTests
  def test_paradigm_context_tracking
    # Test that nodes track which paradigms they use
    function_node = FunctionNode.new(name: "test", body: [])
    assert_includes(function_node.paradigm_context, :functional)
    
    goal_node = GoalNode.new(name: "process", requirements: [])
    assert_includes(goal_node.paradigm_context, :goal_oriented)
    
    event_node = EventHandlerNode.new(source: "user", event: "login")
    assert_includes(event_node.paradigm_context, :event_driven)
  end
  
  def test_visitor_pattern
    # Test AST traversal using visitor pattern
    program = """
      make a function called factorial {
        factorial takes: n - number
        factorial returns: {
          if n <= 1 then 1 else n * factorial(n - 1) end
        }
      }
    """
    
    ast = parser.parse(program)
    visitor = CountingVisitor.new
    ast.accept(visitor)
    
    assert_equal(1, visitor.function_count)
    assert_equal(1, visitor.if_count)
    assert_equal(1, visitor.recursive_call_count)
  end
  
  def test_ast_serialization
    # Test AST can be serialized and deserialized
    original_ast = parser.parse("x = 42; print x")
    
    serialized = serialize_ast(original_ast)
    deserialized_ast = deserialize_ast(serialized)
    
    assert_ast_equivalent(original_ast, deserialized_ast)
  end
  
  def test_ast_optimization
    # Test AST transformations and optimizations
    unoptimized = parser.parse("x = 2 + 3; y = x * 1")
    optimizer = ASTOptimizer.new
    optimized = optimizer.optimize(unoptimized)
    
    # Should constant-fold 2 + 3 to 5 and eliminate * 1
    assert_contains_literal(optimized, 5)
    assert_not_contains_multiplication_by_one(optimized)
  end
end
```

### Evaluator/Interpreter Tests

Tests for the evaluation and execution engine.

```ruby
class EvaluatorTests
  def test_basic_expressions
    # Test arithmetic, logical, comparison operations
    test_cases = [
      { input: "2 + 3 * 4", expected: 14 },
      { input: "10 / 2", expected: 5 },
      { input: "2 ** 3", expected: 8 },
      { input: "true and false", expected: false },
      { input: "not true", expected: false },
      { input: "5 > 3", expected: true },
      { input: "'hello' + ' world'", expected: "hello world" }
    ]
    
    test_cases.each do |test_case|
      result = interpreter.evaluate(test_case[:input])
      assert_equal(test_case[:expected], result.value)
    end
  end
  
  def test_variable_assignment
    # Test natural language assignments
    interpreter.evaluate("age becomes 25")
    result = interpreter.evaluate("age")
    assert_equal(25, result.value)
    
    interpreter.evaluate("name is 'John'")
    result = interpreter.evaluate("name")
    assert_equal("John", result.value)
  end
  
  def test_function_calls
    # Test function definition and calling
    function_def = """
      make a function called double {
        double takes: x - number
        double returns: x * 2
      }
    """
    
    interpreter.evaluate(function_def)
    result = interpreter.evaluate("double(5)")
    assert_equal(10, result.value)
  end
  
  def test_scope_management
    # Test variable scoping rules
    scope_test = """
      x = "global"
      
      make a function called test_scope {
        test_scope returns: {
          x = "local"
          x
        }
      }
      
      local_result = test_scope()
      global_result = x
    """
    
    interpreter.evaluate(scope_test)
    assert_equal("local", interpreter.evaluate("local_result").value)
    assert_equal("global", interpreter.evaluate("global_result").value)
  end
end
```

## 2. Integration Tests for Multi-Paradigm Features

### Cross-Paradigm Data Flow Tests

Tests that validate data passing between different programming paradigms.

```patlang
# Test case: OOP → Functional → Goal-Oriented flow
test_cross_paradigm_data_flow returns: {
  # Setup: Create a data processing class
  make a template called DataProcessor {
    DataProcessor has:
      raw_data - list of number = [1, -2, 3, -4, 5]
      
    process_data returns: {
      # OOP: Object method call
      data = self.raw_data
      
      # Functional: Data transformation pipeline
      processed = data
        |> filter(|x| x > 0)    # Remove negatives
        |> map(|x| x * 2)       # Double values
        |> reduce(|acc, x| acc + x, 0)  # Sum
      
      # Goal-oriented: Process completion
      make a goal called finalize_processing {
        finalize_processing requires:
          result - number
          
        finalize_processing is achieved when:
          result > 0 and result < 100
          
        finalize_processing runs: {
          emit processing_completed with result
          result
        }
      }
      
      activate finalize_processing with [processed]
    }
  }
  
  # Test execution
  processor = DataProcessor.new()
  result = processor.process_data()
  
  assert_equal(18, result)  # (1 + 3 + 5) * 2 = 18
  assert_event_emitted("processing_completed", 18)
}
```

### Event-Driven Integration Tests

Tests for event system integration with other paradigms.

```patlang
# Test case: Event system integration
test_event_integration returns: {
  event_log = []
  
  # Event handler that uses multiple paradigms
  when data: processed is activated {
    result = event_data.result
    
    # Logic programming: Result validation
    query result_is_valid(result) returns:
      result > 0 and
      result < 1000 and
      result is number
    end
    
    if result_is_valid(result) then
      # Functional: Notification creation
      notifications = ["email", "sms", "push"]
        |> filter(|type| is_enabled(type))
        |> map(|type| create_notification(type, result))
      
      # OOP: Notification sender
      sender = NotificationSender.new()
      notifications.each(|notification| {
        sender.send(notification)
      })
      
      # Goal: Track completion
      make a goal called track_completion {
        track_completion is achieved when:
          all_notifications_sent(notifications)
          
        track_completion runs: {
          event_log.add("notifications_sent")
        }
      }
      
      activate track_completion with [notifications]
    end
  }
  
  # Trigger the test
  emit data:processed with { result: 42 }
  
  assert_contains(event_log, "notifications_sent")
}
```

## 3. End-to-End Tests for Complete Programs

### Real-World Application Tests

Tests based on complete applications from `real-world-examples.md`.

#### Web Server Application Test
```patlang
test_web_server_application returns: {
  # Setup test server
  config = ServerConfig.new(port: 8080, test_mode: true)
  server = WebServer.new()
  
  # Test middleware chain
  request = create_test_request("/users", "GET")
  processed_request = server.process_middleware_chain(request)
  assert processed_request.authenticated != nil
  
  # Test route handling
  response = server.handle_request(processed_request)
  assert response.status == 200
  assert response.content_type == "application/json"
  
  # Test event emission
  event_collector = EventCollector.new()
  server.handle_request(create_test_request("/users", "POST"))
  assert event_collector.received_event("user_created")
}
```

#### Data Processing Pipeline Test
```patlang
test_data_pipeline returns: {
  # Setup test pipeline
  config = PipelineConfig.load_from_test_data()
  pipeline = DataPipeline.new()
  
  # Test dependency resolution
  dependency_graph = pipeline.build_stage_dependencies()
  execution_order = dependency_graph.topological_sort()
  assert execution_order.length > 0
  
  # Test pipeline execution
  results = pipeline.execute_pipeline(config)
  assert results.all_successful?
  
  # Test error handling
  failing_config = create_failing_config()
  assert_raises(PipelineError) {
    pipeline.execute_pipeline(failing_config)
  }
}
```

### REPL Functionality Tests

Tests for the interactive development environment.

```patlang
test_repl_functionality returns: {
  repl = PatlangREPL.new()
  
  # Test multi-line input
  repl.input("make a function called test {")
  repl.input("  test returns: 42")
  result = repl.input("}")
  assert result.success?
  
  # Test immediate evaluation
  result = repl.input("test()")
  assert result.value == 42
  
  # Test error handling
  result = repl.input("invalid syntax here")
  assert result.error?
  assert result.error_message.contains("syntax error")
  
  # Test history and editing
  repl.input("previous_command = 'test'")
  repl.recall_history(1)
  assert repl.current_input == "previous_command = 'test'"
  
  # Test variable persistence
  repl.input("x = 10")
  repl.input("y = 20")
  result = repl.input("x + y")
  assert result.value == 30
}
```

## 4. Performance Benchmarking and Regression Testing

### Performance Baseline Tests

```ruby
class PerformanceTests
  def test_parsing_performance
    # Establish parsing speed baselines
    large_program = generate_large_patlang_program(10000) # 10k lines
    
    start_time = Time.now
    ast = parser.parse(large_program)
    parse_time = Time.now - start_time
    
    # Record baseline for future comparison
    record_performance_baseline("parsing", parse_time)
    assert parse_time < 5.0 # Less than 5 seconds for 10k lines
  end
  
  def test_evaluation_performance
    # Test interpreter execution speed
    fibonacci_program = """
      make a function called fibonacci {
        fibonacci takes: n - number
        fibonacci returns: {
          if n <= 1 then n else fibonacci(n-1) + fibonacci(n-2) end
        }
      }
      fibonacci(30)
    """
    
    start_time = Time.now
    result = interpreter.evaluate_program(fibonacci_program)
    eval_time = Time.now - start_time
    
    record_performance_baseline("fibonacci_30", eval_time)
    assert_equal(832040, result.value) # Correct fibonacci(30)
    assert eval_time < 10.0 # Should complete within 10 seconds
  end
  
  def test_memory_usage
    # Monitor memory consumption
    initial_memory = get_memory_usage()
    
    # Execute memory-intensive program
    large_data_program = """
      data = []
      for i in 1..10000:
        data.add(i * i)
      end
      sum = data |> reduce(|acc, x| acc + x, 0)
    """
    
    interpreter.evaluate_program(large_data_program)
    
    final_memory = get_memory_usage()
    memory_growth = final_memory - initial_memory
    
    record_performance_baseline("memory_usage_large_array", memory_growth)
    assert memory_growth < 100 # Less than 100MB growth
  end
  
  def test_multi_paradigm_performance
    # Test performance of paradigm integration
    complex_program = """
      # Complex multi-paradigm scenario
      make a template called OrderProcessor {
        OrderProcessor has:
          orders - list of Order = []
          
        process_orders returns: {
          # Functional pipeline
          valid_orders = orders
            |> filter(|order| validate_order(order))
            |> map(|order| enrich_order(order))
          
          # Goal-oriented processing
          valid_orders.each(|order| {
            make a goal called process_order {
              process_order requires: validated_order - Order
              process_order is achieved when: order.status == "processed"
              process_order runs: {
                # Logic validation
                query order_meets_requirements(order) returns:
                  order.total > 0 and order.customer.valid
                end
                
                if order_meets_requirements(order) then
                  order.status = "processed"
                  emit order:processed with order
                end
              }
            }
            activate process_order with [order]
          })
        }
      }
    """
    
    start_time = Time.now
    interpreter.evaluate_program(complex_program)
    paradigm_time = Time.now - start_time
    
    record_performance_baseline("multi_paradigm_integration", paradigm_time)
  end
end
```

### Memory and Resource Tests

```ruby
class ResourceTests
  def test_garbage_collection
    # Test memory cleanup
    initial_objects = count_interpreter_objects()
    
    # Create many temporary objects
    temp_creation_code = """
      for i in 1..1000:
        temp_obj = TempClass.new(data: "x" * 1000)
      end
    """
    
    interpreter.evaluate(temp_creation_code)
    force_garbage_collection()
    
    final_objects = count_interpreter_objects()
    
    # Should not have significant object growth
    assert (final_objects - initial_objects) < 100
  end
  
  def test_stack_overflow_protection
    # Test recursion limits
    infinite_recursion = """
      make a function called infinite {
        infinite returns: infinite()
      }
      infinite()
    """
    
    assert_raises(StackOverflowError) do
      interpreter.evaluate(infinite_recursion)
    end
  end
end
```

## 5. Conformance Testing Against Language Specification

### Specification Compliance Tests

Tests that validate every aspect of the language specification.

```ruby
class ConformanceTests
  def test_all_syntax_examples
    # Test every syntax example from specification
    syntax_examples = load_syntax_examples_from_spec()
    
    syntax_examples.each do |example|
      assert_parses_correctly(example.code, "Failed to parse: #{example.description}")
      
      if example.expected_result
        result = interpreter.evaluate(example.code)
        assert_equal(example.expected_result, result.value, 
                    "Wrong result for: #{example.description}")
      end
    end
  end
  
  def test_operator_precedence_table
    # Validate operator precedence matches specification exactly
    precedence_tests = [
      { expression: "2 + 3 * 4", expected: 14 },
      { expression: "2 ** 3 * 4", expected: 32 },
      { expression: "true and false or true", expected: true },
      { expression: "not false and true", expected: true },
      { expression: "1 < 2 == true", expected: true }
    ]
    
    precedence_tests.each do |test|
      result = interpreter.evaluate(test[:expression])
      assert_equal(test[:expected], result.value, 
                  "Wrong precedence for: #{test[:expression]}")
    end
  end
  
  def test_reserved_words
    # Ensure all reserved words are properly handled
    reserved_words = load_reserved_words_from_spec()
    
    reserved_words.each do |word|
      # Should fail when used as identifier
      assert_raises(SyntaxError, "#{word} should be reserved") do
        parser.parse("#{word} = 42")
      end
      
      # Should work in proper context
      if word == "function"
        assert_parses("make a function called test { }")
      elsif word == "goal"
        assert_parses("make a goal called test { }")
      end
    end
  end
  
  def test_type_system_compliance
    # Test type system behavior matches specification
    type_tests = [
      { code: "x = 42", expected_type: "number" },
      { code: "x = 'hello'", expected_type: "text" },
      { code: "x = true", expected_type: "boolean" },
      { code: "x = [1, 2, 3]", expected_type: "list of number" },
      { code: "x = |y| y + 1", expected_type: "number -> number" }
    ]
    
    type_tests.each do |test|
      types = type_inferencer.infer_types(test[:code])
      assert_equal(test[:expected_type], types["x"].to_string)
    end
  end
end
```

This comprehensive test categorization ensures that all aspects of the Patlang interpreter are thoroughly validated, from individual components to complete real-world applications.