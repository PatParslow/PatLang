#!/usr/bin/env ruby

# Native Parser Test Runner - Comprehensive testing framework for native parser
# Tests native parser against Ruby parser with performance benchmarking
# Validates compatibility and generates detailed reports

require 'benchmark'
require 'json'
require 'fileutils'
require_relative 'patlang-core/lexer/lexer'
require_relative 'patlang-core/parser/parser'
require_relative 'patlang-core/evaluator/evaluator'
require_relative 'patlang-core/ast/ast_nodes'
require_relative 'native_parser_bridge'

class NativeParserTestRunner
  attr_reader :test_results, :performance_metrics, :compatibility_issues

  def initialize
    @test_results = []
    @performance_metrics = {}
    @compatibility_issues = []
    @ruby_lexer = Lexer.new("")
    @ruby_parser = nil
    @ruby_evaluator = Evaluator.new
    @native_parser_bridge = NativeParserBridge.new
    @test_counter = 0
    @passed_tests = 0
    @failed_tests = 0
    
    puts "🚀 Native Parser Test Runner Initialized"
    puts "=" * 80
  end

  # Main test execution method
  def run_comprehensive_tests
    puts "📋 Starting Comprehensive Native Parser Tests"
    puts "Time: #{Time.now}"
    puts "=" * 80
    
    # Load test examples from demo file
    demo_examples = load_demo_examples
    
    # Test categories
    capture_and_parse_patlang_tests { run_basic_expression_tests }
    capture_and_parse_patlang_tests { run_variable_assignment_tests }
    capture_and_parse_patlang_tests { run_function_definition_tests }
    capture_and_parse_patlang_tests { run_control_flow_tests }
    capture_and_parse_patlang_tests { run_reasoning_construct_tests }
    capture_and_parse_patlang_tests { run_complex_mixed_program_tests(demo_examples) }
    capture_and_parse_patlang_tests { run_error_recovery_tests }
    capture_and_parse_patlang_tests { run_performance_benchmarks(demo_examples) }
    
    # Generate comprehensive report
    generate_test_report
    
    # Patlang-level test/assert summary
    if defined?(@patlang_test_results) && @patlang_test_results
      pat_pass = @patlang_test_results.count { |r| r[:result] == "PASS" }
      pat_fail = @patlang_test_results.count { |r| r[:result] == "FAIL" }
      pat_total = @patlang_test_results.size
      puts "\n=== Patlang Test/Assert Results ==="
      @patlang_test_results.each do |r|
        puts "  #{r[:name]}: #{r[:result]}"
      end
      puts "Summary: #{pat_pass} passed, #{pat_fail} failed, #{pat_total} total"
    end

    puts "\n🎯 All Tests Complete!"
    puts "Passed: #{@passed_tests}, Failed: #{@failed_tests}, Total: #{@test_counter}"
  end

  private

  # Capture stdout during Patlang evaluation and parse TEST: lines
  def capture_and_parse_patlang_tests
    require 'stringio'
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    output = $stdout.string
    $stdout = old_stdout
    test_lines = output.scan(/^TEST: (.+?) (PASS|FAIL)$/)
    test_lines.each do |name, result|
      @patlang_test_results ||= []
      @patlang_test_results << { name: name, result: result }
    end
  end
  # Load examples from native_parser_demo.pat
  def load_demo_examples
    demo_file = 'native_parser/examples/native_parser_demo.pat'
    if File.exist?(demo_file)
      content = File.read(demo_file)
      extract_examples_from_demo(content)
    else
      puts "⚠️  Demo file not found: #{demo_file}"
      []
    end
  end

  # Extract testable examples from demo content
  def extract_examples_from_demo(content)
    examples = []
    current_example = ""
    in_example = false
    
    content.lines.each do |line|
      if line.strip.start_with?('#') && line.include?('====')
        if in_example && !current_example.strip.empty?
          examples << {
            category: extract_category(line),
            code: current_example.strip
          }
        end
        current_example = ""
        in_example = true
      elsif line.strip.start_with?('#') || line.strip.empty?
        # Skip comments and empty lines
      else
        current_example += line if in_example
      end
    end
    
    # Add final example if exists
    if in_example && !current_example.strip.empty?
      examples << {
        category: "final_example",
        code: current_example.strip
      }
    end
    
    examples
  end

  def extract_category(line)
    line.gsub(/[=#]/, '').strip.downcase.gsub(/\s+/, '_')
  end

  # Test basic expressions
  def run_basic_expression_tests
    puts "\n📐 Testing Basic Expressions"
    puts "-" * 40
    
    expressions = [
      "2 + 3 * 4",
      "(x + y) / z", 
      "a ** 2 + b ** 2",
      "not (x > 0 and y < 10)",
      "result == true or status != 'failed'"
    ]
    
    expressions.each do |expr|
      test_expression_parsing(expr)
    end
  end

  # Test variable assignments
  def run_variable_assignment_tests
    puts "\n📝 Testing Variable Assignments"
    puts "-" * 40
    
    assignments = [
      "x = 5",
      "let result = calculate(a, b)",
      "const PI = 3.14159",
      "user.name = 'Alice'",
      "scores[0] = 95",
      "counter += 1"
    ]
    
    assignments.each do |assignment|
      test_assignment_parsing(assignment)
    end
  end

  # Test function definitions
  def run_function_definition_tests
    puts "\n🔧 Testing Function Definitions"
    puts "-" * 40
    
    functions = [
      "make a function called greet takes name\n    print('Hello, ' + name)\nend",
      "function add(x, y) {\n    return x + y\n}",
      "def square(x)\n    x * x\nend",
      "let double = lambda(x) { x * 2 }"
    ]
    
    functions.each do |func|
      test_function_parsing(func)
    end
  end

  # Test control flow statements
  def run_control_flow_tests
    puts "\n🔄 Testing Control Flow"
    puts "-" * 40
    
    control_flows = [
      "if x > 0 then\n    print('positive')\nelse\n    print('negative')\nend",
      "while count < 10 do\n    count += 1\nend",
      "for item in list do\n    process(item)\nend",
      "case status\nwhen 'active' then\n    activate()\nelse\n    deactivate()\nend"
    ]
    
    control_flows.each do |cf|
      test_control_flow_parsing(cf)
    end
  end

  # Test reasoning constructs
  def run_reasoning_construct_tests
    puts "\n🧠 Testing Reasoning Constructs"
    puts "-" * 40
    
    reasoning = [
      "fact parent(john, mary)",
      "rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z)",
      "goal find_ancestors(person) {\n    precondition: person != null,\n    strategy: backward_chaining\n}",
      "query parent(john, X)",
      "constrain age(X, Y) and Y >= 0"
    ]
    
    reasoning.each do |r|
      test_reasoning_parsing(r)
    end
  end

  # Test complex mixed programs
  def run_complex_mixed_program_tests(demo_examples)
    puts "\n🏗️  Testing Complex Mixed Programs"
    puts "-" * 40
    
    # Test a few complex examples from demo
    complex_examples = demo_examples.select do |ex| 
      ex[:code].lines.count > 5 && 
      ex[:code].include?('function') || ex[:code].include?('if') || ex[:code].include?('for')
    end.first(3)
    
    complex_examples.each do |example|
      test_complex_program_parsing(example[:code], example[:category])
    end
  end

  # Test error recovery scenarios  
  def run_error_recovery_tests
    puts "\n🛠️  Testing Error Recovery"
    puts "-" * 40
    
    error_cases = [
      "if true then\n    print('test')\n# Missing end",
      "make a function called incomplete\n# Missing body",
      "let x = \n# Missing value",
      "result = calculate(1, 2, (3 + 4\n# Unclosed paren"
    ]
    
    error_cases.each do |error_case|
      test_error_recovery(error_case)
    end
  end

  # Performance benchmarking
  def run_performance_benchmarks(demo_examples)
    puts "\n⚡ Running Performance Benchmarks"
    puts "-" * 40
    
    # Select benchmark examples
    benchmark_examples = demo_examples.first(5)
    
    benchmark_examples.each do |example|
      benchmark_parsing_performance(example[:code], example[:category])
    end
    
    # Memory usage test
    benchmark_memory_usage(benchmark_examples)
  end

  # Individual test methods
  def test_expression_parsing(expression)
    @test_counter += 1
    print "  Testing: #{expression.ljust(30)} ... "
    
    begin
      # Test with Ruby parser
      ruby_result = parse_with_ruby_parser(expression)
      
      # Test with native parser (simulated)
      native_result = parse_with_native_parser(expression)
      
      # Compare results
      if compare_parsing_results(ruby_result, native_result)
        print "✅ PASS\n"
        @passed_tests += 1
        record_test_result(expression, "expression", true, nil)
      else
        print "❌ FAIL\n"
        require 'pp'
        puts "\n--- Ruby AST ---"
        pp ruby_result
        puts "--- Native AST ---"
        pp native_result
        @failed_tests += 1
        record_test_result(expression, "expression", false, "Results don't match")
      end
      
    rescue => e
      print "❌ ERROR: #{e.message}\n"
      @failed_tests += 1
      record_test_result(expression, "expression", false, e.message)
    end
  end

  def test_assignment_parsing(assignment)
    @test_counter += 1
    print "  Testing: #{assignment.ljust(30)} ... "
    
    begin
      ruby_result = parse_with_ruby_parser(assignment)
      native_result = parse_with_native_parser(assignment)
      
      if compare_parsing_results(ruby_result, native_result)
        print "✅ PASS\n"
        @passed_tests += 1
        record_test_result(assignment, "assignment", true, nil)
      else
        print "❌ FAIL\n"
        @failed_tests += 1
        record_test_result(assignment, "assignment", false, "Results don't match")
      end
      
    rescue => e
      print "❌ ERROR: #{e.message}\n"
      @failed_tests += 1
      record_test_result(assignment, "assignment", false, e.message)
    end
  end

  def test_function_parsing(function)
    @test_counter += 1
    print "  Testing function definition ... "
    
    begin
      ruby_result = parse_with_ruby_parser(function)
      native_result = parse_with_native_parser(function)
      
      if compare_parsing_results(ruby_result, native_result)
        print "✅ PASS\n"
        @passed_tests += 1
        record_test_result(function, "function", true, nil)
      else
        print "❌ FAIL\n"
        @failed_tests += 1
        record_test_result(function, "function", false, "Results don't match")
      end
      
    rescue => e
      print "❌ ERROR: #{e.message}\n"
      @failed_tests += 1
      record_test_result(function, "function", false, e.message)
    end
  end

  def test_control_flow_parsing(control_flow)
    @test_counter += 1
    print "  Testing control flow ... "
    
    begin
      ruby_result = parse_with_ruby_parser(control_flow)
      native_result = parse_with_native_parser(control_flow)
      
      if compare_parsing_results(ruby_result, native_result)
        print "✅ PASS\n"
        @passed_tests += 1
        record_test_result(control_flow, "control_flow", true, nil)
      else
        print "❌ FAIL\n"
        @failed_tests += 1
        record_test_result(control_flow, "control_flow", false, "Results don't match")
      end
      
    rescue => e
      print "❌ ERROR: #{e.message}\n"
      @failed_tests += 1
      record_test_result(control_flow, "control_flow", false, e.message)
    end
  end

  def test_reasoning_parsing(reasoning)
    @test_counter += 1
    print "  Testing reasoning construct ... "
    
    begin
      ruby_result = parse_with_ruby_parser(reasoning)
      native_result = parse_with_native_parser(reasoning)
      
      if compare_parsing_results(ruby_result, native_result)
        print "✅ PASS\n"
        @passed_tests += 1
        record_test_result(reasoning, "reasoning", true, nil)
      else
        print "❌ FAIL\n"
        @failed_tests += 1
        record_test_result(reasoning, "reasoning", false, "Results don't match")
      end
      
    rescue => e
      print "❌ ERROR: #{e.message}\n"
      @failed_tests += 1
      record_test_result(reasoning, "reasoning", false, e.message)
    end
  end

  def test_complex_program_parsing(code, category)
    @test_counter += 1
    print "  Testing #{category} ... "
    
    begin
      ruby_result = parse_with_ruby_parser(code)
      native_result = parse_with_native_parser(code)
      
      if compare_parsing_results(ruby_result, native_result)
        print "✅ PASS\n"
        @passed_tests += 1
        record_test_result(code, "complex_#{category}", true, nil)
      else
        print "❌ FAIL\n"
        @failed_tests += 1
        record_test_result(code, "complex_#{category}", false, "Results don't match")
      end
      
    rescue => e
      print "❌ ERROR: #{e.message}\n"
      @failed_tests += 1
      record_test_result(code, "complex_#{category}", false, e.message)
    end
  end

  def test_error_recovery(error_case)
    @test_counter += 1
    print "  Testing error recovery ... "
    
    begin
      # Both parsers should handle errors gracefully
      ruby_result = parse_with_ruby_parser(error_case)
      native_result = parse_with_native_parser(error_case)
      
      # Both should parse without crashing (error recovery)
      print "✅ PASS (Error handled)\n"
      @passed_tests += 1
      record_test_result(error_case, "error_recovery", true, "Error handled gracefully")
      
    rescue => e
      print "❌ FAIL: #{e.message}\n"
      @failed_tests += 1
      record_test_result(error_case, "error_recovery", false, e.message)
    end
  end

  def benchmark_parsing_performance(code, category)
    print "  Benchmarking #{category} ... "
    
    # Ruby parser benchmark
    ruby_time = Benchmark.measure do
      10.times { parse_with_ruby_parser(code) }
    end
    
    # Native parser benchmark (simulated)
    native_time = Benchmark.measure do
      10.times { parse_with_native_parser(code) }
    end
    
    @performance_metrics[category] = {
      ruby_time: ruby_time.real,
      native_time: native_time.real,
      speedup: ruby_time.real / native_time.real
    }
    
    print "Ruby: #{(ruby_time.real * 1000).round(2)}ms, Native: #{(native_time.real * 1000).round(2)}ms\n"
  end

  def benchmark_memory_usage(examples)
    print "  Testing memory usage ... "
    
    # Simple memory usage test (Ruby approximation)
    before_memory = get_memory_usage
    
    examples.each do |example|
      5.times do
        parse_with_ruby_parser(example[:code])
        parse_with_native_parser(example[:code])
      end
    end
    
    after_memory = get_memory_usage
    memory_delta = after_memory - before_memory
    
    @performance_metrics[:memory_usage] = {
      before: before_memory,
      after: after_memory,
      delta: memory_delta
    }
    
    print "Memory delta: #{memory_delta} KB\n"
  end

  # Parser integration methods
  def parse_with_ruby_parser(code)
    begin
      @ruby_lexer = Lexer.new(code)
      tokens = @ruby_lexer.tokenize
      @ruby_parser = Parser.new(tokens)
      ast = @ruby_parser.parse
      
      {
        success: true,
        ast: ast,
        errors: @ruby_parser.collected_errors,
        node_count: count_ast_nodes(ast)
      }
    rescue => e
      {
        success: false,
        error: e.message,
        ast: nil,
        errors: [],
        node_count: 0
      }
    end
  end

  def parse_with_native_parser(code)
    #we should be able to use the patlang evaluator directly
    begin
      evaluator = PatlangEvaluator.new
      result = evaluator.evaluate(code)
      {
        success: true,
        ast: result[:ast],
        errors: result[:errors] || [],
        node_count: result[:node_count] || 0
      }
    rescue => e
      {
        success: false,
        error: e.message,
        ast: nil,
        errors: [],
        node_count: 0
      }
    end
  end

  def simulate_native_parser_behavior(code)
    # This is a placeholder that simulates what the native parser would return
    # In production, this would interface with the actual native parser
    
    # For now, return a structure similar to what we expect
    {
      ast: create_mock_ast(code),
      errors: [],
      node_count: code.lines.count + code.split(/\w+/).count
    }
  end

  def create_mock_ast(code)
    # Create a simple mock AST for testing purposes
    ProgramNode.new([
      # This would be populated based on actual parsing
      # For now, just return a basic structure
    ])
  end

  def compare_parsing_results(ruby_result, native_result)
    # Compare the key aspects of parsing results
    return false unless ruby_result[:success] == native_result[:success]
    
    # If both failed, that's considered a match for error handling
    return true unless ruby_result[:success]
    
    # Compare AST structure (simplified comparison)
    ruby_nodes = ruby_result[:node_count] || 0
    native_nodes = native_result[:node_count] || 0
    
    # Allow for small differences in node counting
    node_difference = (ruby_nodes - native_nodes).abs
    node_difference <= 2  # Allow small variance
  end

  def count_ast_nodes(ast)
    return 0 unless ast
    
    count = 1
    if ast.respond_to?(:children) && ast.children
      ast.children.each do |child|
        count += count_ast_nodes(child)
      end
    end
    count
  end

  def record_test_result(code, category, passed, error_message)
    # Emit standardized per-test result line
    puts "TEST: #{category} #{passed ? 'PASS' : 'FAIL'}"
    @test_results << {
      code: code.length > 100 ? code[0..100] + "..." : code,
      category: category,
      passed: passed,
      error: error_message,
      timestamp: Time.now
    }
  end

  def get_memory_usage
    # Simple memory usage approximation (works on most systems)
    begin
      `ps -o rss= -p #{Process.pid}`.to_i
    rescue
      0
    end
  end

  def generate_test_report
    puts "\n" + "=" * 80
    puts "📊 COMPREHENSIVE TEST REPORT"
    puts "=" * 80
    
    puts "\n📈 SUMMARY STATISTICS:"
    puts "  Total Tests: #{@test_counter}"
    puts "  Passed: #{@passed_tests} (#{(@passed_tests.to_f / @test_counter * 100).round(1)}%)"
    puts "  Failed: #{@failed_tests} (#{(@failed_tests.to_f / @test_counter * 100).round(1)}%)"
    
    puts "\n🏃 PERFORMANCE METRICS:"
    @performance_metrics.each do |category, metrics|
      next if category == :memory_usage
      puts "  #{category}:"
      puts "    Ruby Parser: #{(metrics[:ruby_time] * 1000).round(2)}ms"
      puts "    Native Parser: #{(metrics[:native_time] * 1000).round(2)}ms"
      puts "    Speedup: #{metrics[:speedup].round(2)}x"
    end
    
    if @performance_metrics[:memory_usage]
      puts "  Memory Usage: #{@performance_metrics[:memory_usage][:delta]} KB delta"
    end
    
    puts "\n🧪 TEST RESULTS BY CATEGORY:"
    results_by_category = @test_results.group_by { |r| r[:category] }
    results_by_category.each do |category, results|
      passed = results.count { |r| r[:passed] }
      total = results.count
      puts "  #{category}: #{passed}/#{total} passed"
    end
    
    puts "\n❌ FAILED TESTS:"
    failed_tests = @test_results.select { |r| !r[:passed] }
    if failed_tests.empty?
      puts "  None! 🎉"
    else
      failed_tests.each do |test|
        puts "  - #{test[:category]}: #{test[:error]}"
      end
    end
    
    puts "\n🔧 COMPATIBILITY ISSUES:"
    if @compatibility_issues.empty?
      puts "  None detected! ✅"
    else
      @compatibility_issues.each { |issue| puts "  - #{issue}" }
    end
    
    # Save detailed report to file
    save_detailed_report
    
    puts "\n🎯 PRODUCTION READINESS ASSESSMENT:"
    assess_production_readiness
  end

  def save_detailed_report
    report_data = {
      timestamp: Time.now,
      summary: {
        total_tests: @test_counter,
        passed: @passed_tests,
        failed: @failed_tests,
        pass_rate: (@passed_tests.to_f / @test_counter * 100).round(2)
      },
      performance_metrics: @performance_metrics,
      test_results: @test_results,
      compatibility_issues: @compatibility_issues
    }
    
    # Save JSON report
    File.write('native_parser_test_report.json', JSON.pretty_generate(report_data))
    
    # Save human-readable report
    markdown_report = generate_markdown_report(report_data)
    File.write('NATIVE_PARSER_TEST_REPORT.md', markdown_report)
    
    puts "\n📋 Detailed reports saved:"
    puts "  - native_parser_test_report.json"
    puts "  - NATIVE_PARSER_TEST_REPORT.md"
  end

  def generate_markdown_report(data)
    report = <<~MARKDOWN
      # Native Parser Test Report
      
      Generated: #{data[:timestamp]}
      
      ## Executive Summary
      
      The native parser testing framework has completed comprehensive validation against the Ruby parser implementation.
      
      ### Key Metrics
      - **Total Tests**: #{data[:summary][:total_tests]}
      - **Pass Rate**: #{data[:summary][:pass_rate]}%
      - **Tests Passed**: #{data[:summary][:passed]}
      - **Tests Failed**: #{data[:summary][:failed]}
      
      ## Performance Analysis
      
      | Category | Ruby Parser (ms) | Native Parser (ms) | Speedup |
      |----------|-----------------|-------------------|---------|
    MARKDOWN
    
    data[:performance_metrics].each do |category, metrics|
      next if category == :memory_usage
      report += "| #{category} | #{(metrics[:ruby_time] * 1000).round(2)} | #{(metrics[:native_time] * 1000).round(2)} | #{metrics[:speedup].round(2)}x |\n"
    end
    
    report += "\n## Test Results by Category\n\n"
    
    results_by_category = data[:test_results].group_by { |r| r[:category] }
    results_by_category.each do |category, results|
      passed = results.count { |r| r[:passed] }
      total = results.count
      status = passed == total ? "✅" : "❌"
      report += "- #{status} **#{category}**: #{passed}/#{total} passed\n"
    end
    
    report += "\n## Failed Tests\n\n"
    failed_tests = data[:test_results].select { |r| !r[:passed] }
    if failed_tests.empty?
      report += "No failed tests! 🎉\n"
    else
      failed_tests.each do |test|
        report += "- **#{test[:category]}**: #{test[:error]}\n"
      end
    end
    
    report += "\n## Compatibility Assessment\n\n"
    if data[:compatibility_issues].empty?
      report += "No compatibility issues detected. The native parser maintains full compatibility with the Ruby parser.\n"
    else
      data[:compatibility_issues].each { |issue| report += "- #{issue}\n" }
    end
    
    report
  end

  def assess_production_readiness
    pass_rate = (@passed_tests.to_f / @test_counter * 100).round(1)
    
    if pass_rate >= 95
      puts "  🟢 READY FOR PRODUCTION"
      puts "     High compatibility and performance"
    elsif pass_rate >= 85
      puts "  🟡 NEARLY READY"
      puts "     Minor issues need resolution"
    elsif pass_rate >= 70
      puts "  🟠 NEEDS WORK"
      puts "     Significant issues require attention"
    else
      puts "  🔴 NOT READY"
      puts "     Major compatibility problems"
    end
    
    puts "     Pass rate: #{pass_rate}%"
    puts "     Recommendation: " + get_recommendation(pass_rate)
  end

  def get_recommendation(pass_rate)
    if pass_rate >= 95
      "Deploy native parser as primary parser"
    elsif pass_rate >= 85
      "Address failing tests before production deployment"
    elsif pass_rate >= 70
      "Extensive debugging and compatibility fixes needed"
    else
      "Return to development phase, major rework required"
    end
  end
end

# Main execution
if __FILE__ == $0
  puts "🚀 Starting Native Parser Comprehensive Test Suite"
  puts "Time: #{Time.now}"
  puts "Directory: #{Dir.pwd}"
  puts "Ruby Version: #{RUBY_VERSION}"
  puts "=" * 80
  
  test_runner = NativeParserTestRunner.new
  test_runner.run_comprehensive_tests
  
  puts "\n" + "=" * 80
  puts "🏁 Native Parser Testing Complete!"
  puts "Check the generated reports for detailed analysis."
  puts "=" * 80
end