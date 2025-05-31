# Patlang Test Infrastructure

## Overview

This document outlines the testing infrastructure, tooling, and automation frameworks needed to support comprehensive testing of the Patlang interpreter.

## 1. Custom Patlang Test Framework Design

### Native Language Testing Framework

A testing framework written in Patlang itself to enable language-native testing.

```patlang
# Patlang-native testing framework
make a template called PatlangTestSuite {
  PatlangTestSuite has:
    test_cases - list of TestCase = []
    results - TestResults
    setup_functions - list of function = []
    teardown_functions - list of function = []
    
  add_setup takes:
    setup_function - function
  add_setup returns: {
    setup_functions.add(setup_function)
  }
  
  add_teardown takes:
    teardown_function - function
  add_teardown returns: {
    teardown_functions.add(teardown_function)
  }
  
  add_test takes:
    name - text
    test_function - function
  add_test returns: {
    test_case = TestCase.new(name, test_function)
    test_cases.add(test_case)
  }
  
  run_all_tests returns: {
    results = TestResults.new()
    
    # Run setup
    setup_functions.each(|setup| setup())
    
    test_cases.each(|test_case| {
      try
        test_case.test_function()
        results.add_success(test_case.name)
        print "."
      catch AssertionError as error
        results.add_failure(test_case.name, error.message)
        print "F"
      catch Exception as error
        results.add_error(test_case.name, error.message)
        print "E"
      end
    })
    
    # Run teardown
    teardown_functions.each(|teardown| teardown())
    
    results.print_summary()
    results
  }
}

# Test case container
make a template called TestCase {
  TestCase has:
    name - text
    test_function - function
    
  TestCase takes:
    test_name - text
    test_func - function
  TestCase returns: {
    name = test_name
    test_function = test_func
  }
}

# Test results tracking
make a template called TestResults {
  TestResults has:
    successes - list of text = []
    failures - list of TestFailure = []
    errors - list of TestError = []
    
  add_success takes:
    test_name - text
  add_success returns: {
    successes.add(test_name)
  }
  
  add_failure takes:
    test_name - text
    message - text
  add_failure returns: {
    failure = TestFailure.new(test_name, message)
    failures.add(failure)
  }
  
  add_error takes:
    test_name - text
    message - text
  add_error returns: {
    error = TestError.new(test_name, message)
    errors.add(error)
  }
  
  print_summary returns: {
    total = successes.length + failures.length + errors.length
    print "\n\nTest Results:"
    print "============="
    print "Total tests: " + total.to_text
    print "Passed: " + successes.length.to_text
    print "Failed: " + failures.length.to_text
    print "Errors: " + errors.length.to_text
    
    if failures.length > 0 then
      print "\nFailures:"
      failures.each(|failure| {
        print "- " + failure.test_name + ": " + failure.message
      })
    end
    
    if errors.length > 0 then
      print "\nErrors:"
      errors.each(|error| {
        print "- " + error.test_name + ": " + error.message
      })
    end
  }
}
```

### Assertion Functions

```patlang
# Core assertion functions
make a function called assert_equal {
  assert_equal takes:
    expected - any
    actual - any
    message - text = ""
  assert_equal returns: {
    if expected != actual then
      error_msg = "Expected #{expected}, got #{actual}"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
  }
}

make a function called assert_true {
  assert_true takes:
    condition - boolean
    message - text = ""
  assert_true returns: {
    if not condition then
      error_msg = "Expected true, got false"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
  }
}

make a function called assert_false {
  assert_false takes:
    condition - boolean
    message - text = ""
  assert_false returns: {
    if condition then
      error_msg = "Expected false, got true"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
  }
}

make a function called assert_nil {
  assert_nil takes:
    value - any
    message - text = ""
  assert_nil returns: {
    if value != nil then
      error_msg = "Expected nil, got #{value}"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
  }
}

make a function called assert_not_nil {
  assert_not_nil takes:
    value - any
    message - text = ""
  assert_not_nil returns: {
    if value == nil then
      error_msg = "Expected non-nil value, got nil"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
  }
}

make a function called assert_raises {
  assert_raises takes:
    expected_error_type - type
    test_function - function
    message - text = ""
  assert_raises returns: {
    error_raised = false
    correct_error_type = false
    
    try
      test_function()
    catch error
      error_raised = true
      if error.type == expected_error_type then
        correct_error_type = true
      end
    end
    
    if not error_raised then
      error_msg = "Expected #{expected_error_type} to be raised, but no error occurred"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
    
    if not correct_error_type then
      error_msg = "Expected #{expected_error_type}, but different error type was raised"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
  }
}

make a function called assert_contains {
  assert_contains takes:
    collection - list
    item - any
    message - text = ""
  assert_contains returns: {
    if not collection.contains(item) then
      error_msg = "Expected collection to contain #{item}"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
  }
}

make a function called assert_type {
  assert_type takes:
    expected_type - type
    value - any
    message - text = ""
  assert_type returns: {
    if value.type != expected_type then
      error_msg = "Expected type #{expected_type}, got #{value.type}"
      if message != "" then
        error_msg = error_msg + ": " + message
      end
      throw AssertionError(error_msg)
    end
  }
}
```

## 2. Ruby Integration Bridge

### Test Bridge Implementation

```ruby
class PatlangTestBridge
  def initialize(interpreter)
    @interpreter = interpreter
    @test_results = []
    @performance_metrics = {}
  end
  
  def run_patlang_test_file(file_path)
    puts "Running Patlang tests from #{file_path}..."
    test_content = File.read(file_path)
    
    begin
      start_time = Time.now
      result = @interpreter.evaluate(test_content)
      duration = Time.now - start_time
      
      @test_results << { 
        file: file_path, 
        status: :passed, 
        duration: duration,
        result: result
      }
      
      puts "✅ #{file_path} passed (#{duration.round(3)}s)"
    rescue PatlangError => e
      @test_results << { 
        file: file_path, 
        status: :failed, 
        error: e.message,
        line: e.line_number,
        column: e.column_number
      }
      
      puts "❌ #{file_path} failed: #{e.message}"
    rescue => e
      @test_results << {
        file: file_path,
        status: :error,
        error: e.message
      }
      
      puts "💥 #{file_path} error: #{e.message}"
    end
  end
  
  def run_interpreter_component_test(test_class)
    puts "Running Ruby component tests for #{test_class}..."
    test_instance = test_class.new(@interpreter)
    
    test_methods = test_instance.methods.select { |m| m.to_s.start_with?('test_') }
    
    test_methods.each do |method|
      begin
        start_time = Time.now
        test_instance.send(method)
        duration = Time.now - start_time
        
        puts "  ✅ #{method} (#{duration.round(3)}s)"
      rescue => e
        puts "  ❌ #{method}: #{e.message}"
        puts "     #{e.backtrace.first}"
      end
    end
  end
  
  def generate_test_report
    report = TestReport.new(@test_results, @performance_metrics)
    report.generate_html_report("test_results.html")
    report.generate_console_summary
    report
  end
  
  def measure_performance(test_name, &block)
    start_time = Time.now
    start_memory = get_memory_usage
    
    result = block.call
    
    end_time = Time.now
    end_memory = get_memory_usage
    
    @performance_metrics[test_name] = {
      duration: end_time - start_time,
      memory_used: end_memory - start_memory,
      result: result
    }
    
    result
  end
  
  private
  
  def get_memory_usage
    # Ruby memory usage measurement
    `ps -o rss= -p #{Process.pid}`.to_i * 1024 # Convert KB to bytes
  end
end
```

### Test Report Generation

```ruby
class TestReport
  def initialize(test_results, performance_metrics)
    @test_results = test_results
    @performance_metrics = performance_metrics
    @timestamp = Time.now
  end
  
  def generate_html_report(filename)
    html_content = build_html_report
    File.write(filename, html_content)
    puts "📄 HTML report generated: #{filename}"
  end
  
  def generate_console_summary
    puts "\n" + "="*60
    puts "PATLANG TEST SUMMARY"
    puts "="*60
    
    total_tests = @test_results.length
    passed = @test_results.count { |r| r[:status] == :passed }
    failed = @test_results.count { |r| r[:status] == :failed }
    errors = @test_results.count { |r| r[:status] == :error }
    
    puts "Total Tests: #{total_tests}"
    puts "Passed: #{passed} (#{percentage(passed, total_tests)}%)"
    puts "Failed: #{failed} (#{percentage(failed, total_tests)}%)"
    puts "Errors: #{errors} (#{percentage(errors, total_tests)}%)"
    
    if failed > 0 || errors > 0
      puts "\nFAILURES AND ERRORS:"
      @test_results.each do |result|
        if result[:status] != :passed
          puts "❌ #{result[:file]}: #{result[:error]}"
        end
      end
    end
    
    if @performance_metrics.any?
      puts "\nPERFORMANCE METRICS:"
      @performance_metrics.each do |test_name, metrics|
        puts "⏱️  #{test_name}: #{metrics[:duration].round(3)}s, #{format_memory(metrics[:memory_used])}"
      end
    end
    
    puts "="*60
  end
  
  private
  
  def build_html_report
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Patlang Test Report - #{@timestamp.strftime("%Y-%m-%d %H:%M:%S")}</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
          .summary { display: flex; gap: 20px; margin: 20px 0; }
          .metric { background: #e8f4fd; padding: 15px; border-radius: 5px; flex: 1; text-align: center; }
          .passed { background: #d4edda; }
          .failed { background: #f8d7da; }
          .error { background: #fff3cd; }
          .test-list { margin-top: 20px; }
          .test-item { padding: 10px; margin: 5px 0; border-radius: 3px; }
          .performance { margin-top: 30px; }
          table { width: 100%; border-collapse: collapse; }
          th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>Patlang Test Report</h1>
          <p>Generated: #{@timestamp}</p>
        </div>
        
        #{build_summary_section}
        #{build_test_results_section}
        #{build_performance_section}
      </body>
      </html>
    HTML
  end
  
  def build_summary_section
    total = @test_results.length
    passed = @test_results.count { |r| r[:status] == :passed }
    failed = @test_results.count { |r| r[:status] == :failed }
    errors = @test_results.count { |r| r[:status] == :error }
    
    <<~HTML
      <div class="summary">
        <div class="metric">
          <h3>Total Tests</h3>
          <div style="font-size: 24px; font-weight: bold;">#{total}</div>
        </div>
        <div class="metric passed">
          <h3>Passed</h3>
          <div style="font-size: 24px; font-weight: bold;">#{passed}</div>
          <div>#{percentage(passed, total)}%</div>
        </div>
        <div class="metric failed">
          <h3>Failed</h3>
          <div style="font-size: 24px; font-weight: bold;">#{failed}</div>
          <div>#{percentage(failed, total)}%</div>
        </div>
        <div class="metric error">
          <h3>Errors</h3>
          <div style="font-size: 24px; font-weight: bold;">#{errors}</div>
          <div>#{percentage(errors, total)}%</div>
        </div>
      </div>
    HTML
  end
  
  def build_test_results_section
    html = '<div class="test-list"><h2>Test Results</h2>'
    
    @test_results.each do |result|
      status_class = result[:status].to_s
      status_icon = case result[:status]
                   when :passed then "✅"
                   when :failed then "❌"
                   when :error then "💥"
                   end
      
      html += <<~HTML
        <div class="test-item #{status_class}">
          <strong>#{status_icon} #{File.basename(result[:file])}</strong>
      HTML
      
      if result[:duration]
        html += " <em>(#{result[:duration].round(3)}s)</em>"
      end
      
      if result[:error]
        html += "<br><code>#{result[:error]}</code>"
      end
      
      html += "</div>"
    end
    
    html + '</div>'
  end
  
  def build_performance_section
    return "" if @performance_metrics.empty?
    
    html = '<div class="performance"><h2>Performance Metrics</h2><table>'
    html += '<tr><th>Test</th><th>Duration</th><th>Memory Used</th></tr>'
    
    @performance_metrics.each do |test_name, metrics|
      html += <<~HTML
        <tr>
          <td>#{test_name}</td>
          <td>#{metrics[:duration].round(3)}s</td>
          <td>#{format_memory(metrics[:memory_used])}</td>
        </tr>
      HTML
    end
    
    html + '</table></div>'
  end
  
  def percentage(part, total)
    return 0 if total == 0
    ((part.to_f / total) * 100).round(1)
  end
  
  def format_memory(bytes)
    if bytes < 1024
      "#{bytes}B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(1)}KB"
    else
      "#{(bytes / (1024.0 * 1024)).round(1)}MB"
    end
  end
end
```

## 3. Test Harness for Patlang Programs

### Program Execution Testing

```ruby
class PatlangProgramTester
  def initialize
    @interpreter = PatlangInterpreter.new
    @test_environment = TestEnvironment.new
  end
  
  def test_program_execution(program_path, expected_output = nil)
    program_content = File.read(program_path)
    
    # Capture output during execution
    output_capture = OutputCapture.new
    @interpreter.set_output_handler(output_capture)
    
    begin
      result = @interpreter.evaluate_program(program_content)
      
      if expected_output
        actual_output = output_capture.captured_output.strip
        assert_equal(expected_output.strip, actual_output,
                    "Output mismatch for #{program_path}")
      end
      
      { status: :success, result: result, output: output_capture.captured_output }
    rescue => e
      { status: :error, error: e.message, output: output_capture.captured_output }
    end
  end
  
  def test_program_with_inputs(program_path, inputs, expected_outputs)
    program_content = File.read(program_path)
    
    input_provider = MockInputProvider.new(inputs)
    output_capture = OutputCapture.new
    
    @interpreter.set_input_handler(input_provider)
    @interpreter.set_output_handler(output_capture)
    
    @interpreter.evaluate_program(program_content)
    
    outputs = output_capture.captured_lines
    
    expected_outputs.each_with_index do |expected, index|
      assert_equal(expected, outputs[index], 
                  "Output line #{index + 1} mismatch in #{program_path}")
    end
  end
  
  def test_program_performance(program_path, max_duration = nil, max_memory = nil)
    program_content = File.read(program_path)
    
    start_time = Time.now
    start_memory = get_memory_usage()
    
    result = @interpreter.evaluate_program(program_content)
    
    end_time = Time.now
    end_memory = get_memory_usage()
    
    duration = end_time - start_time
    memory_used = end_memory - start_memory
    
    if max_duration && duration > max_duration
      raise PerformanceError.new("Program took #{duration}s, expected < #{max_duration}s")
    end
    
    if max_memory && memory_used > max_memory
      raise PerformanceError.new("Program used #{memory_used} bytes, expected < #{max_memory} bytes")
    end
    
    {
      result: result,
      duration: duration,
      memory_used: memory_used
    }
  end
end
```

### Multi-Paradigm Integration Tester

```ruby
class MultiParadigmTester
  def test_paradigm_interaction(test_scenario)
    interpreter = setup_test_interpreter()
    
    # Setup phase: Load required definitions
    test_scenario.setup_code.each do |code|
      interpreter.evaluate(code)
    end
    
    # Execution phase: Run test steps
    results = {}
    test_scenario.test_steps.each do |step|
      case step.type
      when :oop_interaction
        results[step.name] = test_oop_behavior(interpreter, step)
      when :functional_pipeline
        results[step.name] = test_functional_pipeline(interpreter, step)
      when :goal_activation
        results[step.name] = test_goal_activation(interpreter, step)
      when :event_emission
        results[step.name] = test_event_emission(interpreter, step)
      when :logic_query
        results[step.name] = test_logic_query(interpreter, step)
      end
    end
    
    # Validation phase: Check expected outcomes
    test_scenario.validations.each do |validation|
      assert_validation_passed(results, validation)
    end
    
    results
  end
  
  private
  
  def test_oop_behavior(interpreter, step)
    object = interpreter.evaluate(step.object_creation)
    method_result = object.call_method(step.method_name, step.arguments)
    
    {
      object_created: !object.nil?,
      method_result: method_result,
      object_state: object.get_all_properties
    }
  end
  
  def test_functional_pipeline(interpreter, step)
    pipeline_result = interpreter.evaluate(step.pipeline_code)
    
    {
      pipeline_executed: true,
      result: pipeline_result,
      intermediate_values: interpreter.get_pipeline_intermediate_values
    }
  end
  
  def test_goal_activation(interpreter, step)
    goal_tracker = interpreter.get_goal_tracker
    initial_goal_count = goal_tracker.active_goals.length
    
    activation_result = interpreter.evaluate(step.activation_code)
    
    {
      goal_activated: goal_tracker.active_goals.length > initial_goal_count,
      activation_result: activation_result,
      goal_state: goal_tracker.get_goal_state(step.goal_name)
    }
  end
  
  def test_event_emission(interpreter, step)
    event_collector = MockEventCollector.new
    interpreter.set_event_collector(event_collector)
    
    interpreter.evaluate(step.emission_code)
    
    {
      events_emitted: event_collector.events_received.length,
      event_data: event_collector.events_received,
      handlers_triggered: event_collector.handlers_triggered
    }
  end
  
  def test_logic_query(interpreter, step)
    query_result = interpreter.evaluate(step.query_code)
    
    {
      query_executed: true,
      results: query_result,
      facts_used: interpreter.get_logic_engine.facts_accessed,
      rules_applied: interpreter.get_logic_engine.rules_applied
    }
  end
end
```

## 4. Automated Testing Pipeline Configuration

### Continuous Integration Setup

```yaml
# .github/workflows/patlang-tests.yml
name: Patlang Interpreter Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        ruby-version: [3.0, 3.1, 3.2]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: ${{ matrix.ruby-version }}
    
    - name: Install dependencies
      run: |
        gem install bundler
        bundle install
    
    - name: Run Lexer Tests
      run: bundle exec ruby test/unit/lexer_tests.rb
    
    - name: Run Parser Tests
      run: bundle exec ruby test/unit/parser_tests.rb
    
    - name: Run AST Tests
      run: bundle exec ruby test/unit/ast_tests.rb
    
    - name: Run Interpreter Tests
      run: bundle exec ruby test/unit/interpreter_tests.rb
    
    - name: Run Multi-Paradigm Integration Tests
      run: bundle exec ruby test/integration/multi_paradigm_tests.rb
    
    - name: Run Patlang Native Tests
      run: bundle exec ruby test/patlang/run_patlang_tests.rb
    
    - name: Run Real-World Example Tests
      run: bundle exec ruby test/examples/real_world_tests.rb
    
    - name: Run Performance Baseline Tests
      run: bundle exec ruby test/performance/baseline_tests.rb
    
    - name: Generate Test Coverage Report
      run: bundle exec ruby test/coverage/generate_report.rb
    
    - name: Upload Coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage/coverage.xml
```

### Test Automation Scripts

```ruby
#!/usr/bin/env ruby
# test/automation/test_runner.rb

class PatlangTestRunner
  def initialize
    @interpreter = PatlangInterpreter.new
    @test_bridge = PatlangTestBridge.new(@interpreter)
    @test_suites = load_test_suites
    @results = []
  end
  
  def run_all_tests
    puts "🚀 Running Patlang Interpreter Test Suite..."
    puts "Ruby Version: #{RUBY_VERSION}"
    puts "=" * 60
    
    @test_suites.each do |suite_name, suite_config|
      puts "\n📁 Running #{suite_name}..."
      
      case suite_config[:type]
      when :ruby_unit
        run_ruby_unit_tests(suite_config[:files])
      when :patlang_native
        run_patlang_native_tests(suite_config[:files])
      when :integration
        run_integration_tests(suite_config[:scenarios])
      when :performance
        run_performance_tests(suite_config[:benchmarks])
      end
    end
    
    generate_final_report
  end
  
  private
  
  def load_test_suites
    {
      'Core Infrastructure' => {
        type: :ruby_unit,
        files: [
          'test/unit/lexer_tests.rb',
          'test/unit/parser_tests.rb',
          'test/unit/ast_tests.rb',
          'test/unit/interpreter_tests.rb'
        ]
      },
      'Language Features' => {
        type: :patlang_native,
        files: Dir.glob('test/patlang/features/*.patlang')
      },
      'Multi-Paradigm Integration' => {
        type: :integration,
        scenarios: Dir.glob('test/integration/scenarios/*.json')
      },
      'Real-World Examples' => {
        type: :patlang_native,
        files: Dir.glob('test/examples/*.patlang')
      },
      'Performance Baselines' => {
        type: :performance,
        benchmarks: Dir.glob('test/performance/benchmarks/*.rb')
      }
    }
  end
  
  def run_ruby_unit_tests(test_files)
    test_files.each do |file|
      require_relative "../#{file}"
      test_class_name = File.basename(file, '.rb').split('_').map(&:capitalize).join
      test_class = Object.const_get(test_class_name)
      @test_bridge.run_interpreter_component_test(test_class)
    end
  end
  
  def run_patlang_native_tests(test_files)
    test_files.each do |file|
      @test_bridge.run_patlang_test_file(file)
    end
  end
  
  def run_integration_tests(scenario_files)
    scenario_files.each do |scenario_file|
      scenario = JSON.parse(File.read(scenario_file))
      multi_paradigm_tester = MultiParadigmTester.new
      multi_paradigm_tester.test_paradigm_interaction(scenario)
    end
  end
  
  def run_performance_tests(benchmark_files)
    benchmark_files.each do |file|
      @test_bridge.measure_performance(File.basename(file, '.rb')) do
        require_relative "../#{file}"
      end
    end
  end
  
  def generate_final_report
    puts "\n" + "=" * 60
    report = @test_bridge.generate_test_report
    
    if report.all_passed?
      puts "🎉 All tests passed!"
      exit 0
    else
      puts "❌ Some tests failed. Check the report for details."
      exit 1
    end
  end
end

# Run tests if called directly
if __FILE__ == $0
  runner = PatlangTestRunner.new
  runner.run_all_tests
end
```

This comprehensive test infrastructure provides:

1. **Native Patlang Testing Framework** - Tests written in Patlang itself
2. **Ruby Integration Bridge** - Seamless integration with Ruby testing
3. **Automated Test Execution** - CI/CD pipeline integration
4. **Performance Monitoring** - Built-in performance tracking
5. **Comprehensive Reporting** - HTML and console test reports
6. **Multi-Paradigm Testing** - Specialized tools for paradigm integration testing

The infrastructure supports both Ruby-based component testing and Patlang-native language testing, ensuring comprehensive validation of the interpreter while maintaining the language-first testing philosophy.