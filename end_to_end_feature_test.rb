#!/usr/bin/env ruby

# =============================================================================
# END-TO-END PATLANG FEATURE TESTING SUITE
# =============================================================================
# 
# This comprehensive test suite systematically tests what actually works in 
# PaTLang versus what should work according to the specification.
#
# Testing Strategy:
# 1. Test through Ruby evaluator (existing implementation)
# 2. Test through Phase 1 self-hosting bridge
# 3. Test object model capabilities 
# 4. Document exactly what works, fails, and how
# 5. Performance benchmarks for working features
#
# =============================================================================

require 'json'
require 'benchmark'
require 'timeout'

# Load PaTLang components with error handling
begin
  require_relative 'patlang-core/lexer/lexer'
  require_relative 'patlang-core/parser/parser'
  require_relative 'patlang-core/evaluator/evaluator'
  CORE_COMPONENTS_AVAILABLE = true
rescue LoadError => e
  puts "Warning: Core components not available: #{e.message}"
  CORE_COMPONENTS_AVAILABLE = false
end

begin
  require_relative 'native_evaluator/ruby_bridge'
  PHASE1_BRIDGE_AVAILABLE = true
rescue LoadError => e
  puts "Warning: Phase 1 bridge not available: #{e.message}"
  PHASE1_BRIDGE_AVAILABLE = false
end

begin
  require_relative 'patlang-core/object_model/patlang_object'
  require_relative 'patlang-core/object_model/event_system'
  require_relative 'patlang-core/object_model/object_integration'
  OBJECT_MODEL_AVAILABLE = true
rescue LoadError => e
  puts "Warning: Object model not available: #{e.message}"
  OBJECT_MODEL_AVAILABLE = false
end

class EndToEndFeatureTestSuite
  def initialize
    @test_results = {
      meta: {
        test_suite_version: "1.0.0",
        timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
        total_tests: 0,
        passed_tests: 0,
        failed_tests: 0,
        implementation_coverage: {}
      },
      feature_categories: {},
      performance_benchmarks: {},
      implementation_comparison: {},
      critical_gaps: [],
      working_features: [],
      broken_features: []
    }
    
    @phase1_bridge = nil
    @timeout_seconds = 10
    
    puts "🧪 PATLANG END-TO-END FEATURE TESTING SUITE"
    puts "=" * 60
    puts "Testing actual implementation vs specification..."
    puts
  end
  
  def run_comprehensive_test_suite
    puts "🚀 Starting comprehensive end-to-end feature testing...\n"
    
    # Initialize bridges and components
    initialize_test_environment
    
    # Core language feature tests
    test_arithmetic_operations
    test_string_operations  
    test_control_flow
    test_variable_assignment
    
    # Advanced language feature tests
    test_function_definitions
    test_natural_language_syntax
    test_event_system
    test_goal_oriented_programming
    test_logic_programming
    test_template_system
    
    # Implementation comparison tests
    test_ruby_vs_patlang_evaluator
    test_phase1_bridge_capabilities
    
    # Performance benchmarks
    run_performance_benchmarks
    
    # Generate comprehensive report
    generate_final_report
    
    cleanup_test_environment
  end
  
  private
  
  def initialize_test_environment
    puts "🔧 Initializing test environment..."
    
    if PHASE1_BRIDGE_AVAILABLE
      begin
        @phase1_bridge = PaTLangPhase1Bridge.new
        puts "  ✅ Phase 1 bridge initialized"
      rescue => e
        puts "  ❌ Phase 1 bridge failed: #{e.message}"
        @phase1_bridge = nil
      end
    else
      puts "  ⚠️  Phase 1 bridge not available - components missing"
      @phase1_bridge = nil
    end
    
    if CORE_COMPONENTS_AVAILABLE
      @evaluator = Evaluator.new
      puts "  ✅ Ruby evaluator initialized"
    else
      puts "  ❌ Ruby evaluator not available - core components missing"
      @evaluator = nil
    end
    
    puts "  📊 Component availability:"
    puts "    Core Components: #{CORE_COMPONENTS_AVAILABLE ? '✅' : '❌'}"
    puts "    Phase 1 Bridge: #{PHASE1_BRIDGE_AVAILABLE ? '✅' : '❌'}"
    puts "    Object Model: #{OBJECT_MODEL_AVAILABLE ? '✅' : '❌'}"
    puts
  end
  
  # ==========================================================================
  # CORE LANGUAGE FEATURE TESTS
  # ==========================================================================
  
  def test_arithmetic_operations
    test_category("Arithmetic Operations", "Basic mathematical expressions and operations") do
      
      test_cases = [
        { code: "42", expected: 42, description: "Integer literal" },
        { code: "3.14", expected: 3.14, description: "Float literal" },
        { code: "2 + 3", expected: 5, description: "Addition" },
        { code: "10 - 5", expected: 5, description: "Subtraction" },
        { code: "3 * 4", expected: 12, description: "Multiplication" },
        { code: "15 / 3", expected: 5, description: "Division" },
        { code: "17 % 5", expected: 2, description: "Modulo" },
        { code: "2 + 3 * 4", expected: 14, description: "Operator precedence" },
        { code: "(2 + 3) * 4", expected: 20, description: "Parentheses grouping" },
        { code: "3.14 + 2.86", expected: 6.0, description: "Float arithmetic" },
        { code: "5 + 2.5", expected: 7.5, description: "Mixed int/float" }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  def test_string_operations
    test_category("String Operations", "String literals, concatenation, and methods") do
      
      test_cases = [
        { code: '"Hello"', expected: "Hello", description: "String literal" },
        { code: '"Hello" + " World"', expected: "Hello World", description: "String concatenation" },
        { code: '"Hello" + " " + "World"', expected: "Hello World", description: "Multiple concatenation" },
        { code: '"test".length', expected: 4, description: "String length method", expected_to_fail: true },
        { code: '"HELLO".lowercase', expected: "hello", description: "String lowercase method", expected_to_fail: true }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  def test_control_flow
    test_category("Control Flow", "Conditional statements and loops") do
      
      test_cases = [
        { 
          code: "if true then 1 else 2 end", 
          expected: 1, 
          description: "Basic if-then-else" 
        },
        { 
          code: "if false then 1 else 2 end", 
          expected: 2, 
          description: "If-else with false condition" 
        },
        { 
          code: "if 5 > 3 then \"greater\" else \"lesser\" end", 
          expected: "greater", 
          description: "If with comparison" 
        },
        {
          code: "x = 0\nwhile x < 3 do\n  x = x + 1\nend\nx",
          expected: 3,
          description: "While loop",
          expected_to_fail: true
        }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  def test_variable_assignment
    test_category("Variable Assignment", "Variable declaration and assignment") do
      
      test_cases = [
        { code: "x = 5\nx", expected: 5, description: "Simple assignment" },
        { code: "y = 2 + 3\ny", expected: 5, description: "Assignment with expression" },
        { code: "name = \"John\"\nname", expected: "John", description: "String assignment" },
        { code: "a = 1\nb = a + 2\nb", expected: 3, description: "Variable reference" }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  # ==========================================================================
  # ADVANCED LANGUAGE FEATURE TESTS
  # ==========================================================================
  
  def test_function_definitions
    test_category("Function Definitions", "Natural language function syntax") do
      
      test_cases = [
        {
          code: "make a function called greet {\n  return \"Hello, World!\"\n}\ncall greet",
          expected: "Hello, World!",
          description: "Simple function definition and call",
          expected_to_fail: true
        },
        {
          code: "make a function called add takes: x, y {\n  return x + y\n}\ncall add with 3, 4",
          expected: 7,
          description: "Function with parameters",
          expected_to_fail: true
        },
        {
          code: "make a function called square takes: x returns: number {\n  return x * x\n}\ncall square with 4",
          expected: 16,
          description: "Function with type annotation",
          expected_to_fail: true
        }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  def test_natural_language_syntax
    test_category("Natural Language Syntax", "English-like programming constructs") do
      
      test_cases = [
        {
          code: "create a variable called counter with value 0",
          expected: 0,
          description: "Natural variable declaration",
          expected_to_fail: true
        },
        {
          code: "set counter to 5",
          expected: 5,
          description: "Natural assignment",
          expected_to_fail: true
        },
        {
          code: "if counter is greater than 3 then say \"large\" else say \"small\"",
          expected: "large",
          description: "Natural conditional",
          expected_to_fail: true
        }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  def test_event_system
    test_category("Event System", "Object events and reactive programming") do
      
      # Test the working object event system
      test_case = {
        description: "Object model event system (Ruby implementation)",
        test_proc: -> {
          if OBJECT_MODEL_AVAILABLE
            begin
              # Create objects and test events
              obj = PatlangObject.create_number(42)
              event_fired = false
              
              obj.on_event(:value_changed) do |event|
                event_fired = true
              end
              
              obj.value = 100
              
              obj.destroy
              
              { success: event_fired, value: event_fired, implementation: "ruby_object_model" }
            rescue => e
              { success: false, error: e.message, implementation: "ruby_object_model" }
            end
          else
            { success: false, error: "Object model not available", implementation: "ruby_object_model" }
          end
        }
      }
      
      result = test_case[:test_proc].call
      record_test_result("Event System - Object Events", result, test_case[:description])
      
      # Test natural language event syntax (expected to fail)
      natural_event_cases = [
        {
          code: "when temperature_sensor changes:\n  print \"Temperature updated\"",
          expected: nil,
          description: "Natural event handler syntax",
          expected_to_fail: true
        },
        {
          code: "temperature connects to display:\n  \"Temp: {temperature}°C\"",
          expected: nil,
          description: "Reactive connection syntax", 
          expected_to_fail: true
        }
      ]
      
      natural_event_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  def test_goal_oriented_programming
    test_category("Goal-Oriented Programming", "Goal definitions and constraint solving") do
      
      test_cases = [
        {
          code: "goal calculate_sum(x, y) {\n  precondition: x >= 0 and y >= 0,\n  postcondition: result >= 0\n}",
          expected: nil,
          description: "Basic goal definition",
          expected_to_fail: true
        },
        {
          code: "fact user_age(john, 25)\nfact user_age(jane, 30)",
          expected: nil,
          description: "Fact assertions",
          expected_to_fail: true
        },
        {
          code: "rule adult(X) :- user_age(X, Age), Age >= 18",
          expected: nil,
          description: "Logical rule definition",
          expected_to_fail: true
        }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  def test_logic_programming
    test_category("Logic Programming", "Prolog-style logic constructs") do
      
      test_cases = [
        {
          code: "parent(tom, bob)\nparent(bob, ann)\ngrandparent(X, Z) :- parent(X, Y), parent(Y, Z)",
          expected: nil,
          description: "Logic programming facts and rules",
          expected_to_fail: true
        },
        {
          code: "query grandparent(tom, X)",
          expected: nil,
          description: "Logic query",
          expected_to_fail: true
        }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  def test_template_system
    test_category("Template System", "Class-like templates and instances") do
      
      test_cases = [
        {
          code: "template Person {\n  name: string,\n  age: number\n}",
          expected: nil,
          description: "Template definition",
          expected_to_fail: true
        },
        {
          code: "person1 = create Person with name=\"John\", age=25",
          expected: nil,
          description: "Template instantiation",
          expected_to_fail: true
        }
      ]
      
      test_cases.each do |test_case|
        run_multi_implementation_test(test_case)
      end
    end
  end
  
  # ==========================================================================
  # IMPLEMENTATION COMPARISON TESTS
  # ==========================================================================
  
  def test_ruby_vs_patlang_evaluator
    test_category("Ruby vs PaTLang Evaluator", "Comparing implementation behaviors") do
      
      if @phase1_bridge
        test_cases = [
          "42",
          "2 + 3 * 4", 
          "(2 + 3) * 4",
          "\"Hello \" + \"World\"",
          "x = 5\nx + 2"
        ]
        
        test_cases.each do |code|
          # Test with Ruby evaluator preference
          ruby_result = test_with_timeout { @phase1_bridge.evaluate(code, prefer_patlang: false) }
          
          # Test with PaTLang evaluator preference  
          patlang_result = test_with_timeout { @phase1_bridge.evaluate(code, prefer_patlang: true) }
          
          comparison = {
            code: code,
            ruby_result: ruby_result,
            patlang_result: patlang_result,
            results_match: ruby_result[:value] == patlang_result[:value],
            ruby_success: ruby_result[:success],
            patlang_success: patlang_result[:success]
          }
          
          @test_results[:implementation_comparison][code] = comparison
          
          puts "    📊 #{code}"
          puts "      Ruby: #{ruby_result[:value]} (#{ruby_result[:evaluator_used]})"
          puts "      PaTLang: #{patlang_result[:value]} (#{patlang_result[:evaluator_used]})"
          puts "      Match: #{comparison[:results_match] ? '✅' : '❌'}"
        end
      else
        puts "    ❌ Phase 1 bridge not available - skipping comparison tests"
      end
    end
  end
  
  def test_phase1_bridge_capabilities
    test_category("Phase 1 Bridge Capabilities", "Self-hosting bridge functionality") do
      
      if @phase1_bridge
        # Test bridge statistics
        stats = @phase1_bridge.get_evaluation_statistics
        puts "    📊 Bridge Statistics:"
        stats.each { |k, v| puts "      #{k}: #{v}" }
        
        # Test native bridge operations
        if stats[:native_bridge_initialized]
          memory_test = @phase1_bridge.allocate_memory(1024)
          puts "    🧠 Memory allocation test: #{memory_test ? 'SUCCESS' : 'FAILED'}"
          
          bridge_stats = @phase1_bridge.get_bridge_statistics
          puts "    📈 Native bridge stats:"
          bridge_stats.each { |k, v| puts "      #{k}: #{v}" }
        else
          puts "    ⚠️  Native bridge not available"
        end
        
        record_test_result("Phase 1 Bridge", { success: true, value: stats }, "Bridge functionality test")
      else
        record_test_result("Phase 1 Bridge", { success: false, error: "Bridge not initialized" }, "Bridge availability test")
      end
    end
  end
  
  # ==========================================================================
  # PERFORMANCE BENCHMARKS
  # ==========================================================================
  
  def run_performance_benchmarks
    test_category("Performance Benchmarks", "Speed and efficiency measurements") do
      
      benchmark_cases = [
        {
          name: "Simple Arithmetic",
          code: "2 + 3 * 4",
          iterations: 1000
        },
        {
          name: "String Operations", 
          code: '"Hello" + " " + "World"',
          iterations: 1000
        },
        {
          name: "Variable Assignment",
          code: "x = 42\ny = x + 8\ny",
          iterations: 500
        }
      ]
      
      benchmark_cases.each do |bench|
        puts "    ⚡ Benchmarking: #{bench[:name]}"
        
        # Ruby evaluator benchmark
        ruby_time = Benchmark.measure do
          bench[:iterations].times do
            begin
              lexer = Lexer.new(bench[:code])
              tokens = lexer.tokenize
              parser = Parser.new(tokens)
              ast = parser.parse
              @evaluator.evaluate(ast)
            rescue => e
              # Skip failed evaluations
            end
          end
        end
        
        ruby_avg = (ruby_time.real * 1000) / bench[:iterations]
        
        benchmark_result = {
          ruby_evaluator: {
            total_time: ruby_time.real,
            average_time_ms: ruby_avg,
            iterations: bench[:iterations]
          }
        }
        
        # Phase 1 bridge benchmark (if available)
        if @phase1_bridge
          bridge_time = Benchmark.measure do
            bench[:iterations].times do
              begin
                @phase1_bridge.evaluate(bench[:code])
              rescue => e
                # Skip failed evaluations
              end
            end
          end
          
          bridge_avg = (bridge_time.real * 1000) / bench[:iterations]
          benchmark_result[:phase1_bridge] = {
            total_time: bridge_time.real,
            average_time_ms: bridge_avg,
            iterations: bench[:iterations]
          }
        end
        
        @test_results[:performance_benchmarks][bench[:name]] = benchmark_result
        
        puts "      Ruby: #{ruby_avg.round(3)}ms/op"
        if benchmark_result[:phase1_bridge]
          puts "      Bridge: #{benchmark_result[:phase1_bridge][:average_time_ms].round(3)}ms/op"
        end
      end
    end
  end
  
  # ==========================================================================
  # HELPER METHODS
  # ==========================================================================
  
  def test_category(name, description, &block)
    puts "📂 #{name}"
    puts "   #{description}"
    puts
    
    @test_results[:feature_categories][name] = {
      description: description,
      tests: [],
      passed: 0,
      failed: 0
    }
    
    @current_category = name
    block.call
    
    category_stats = @test_results[:feature_categories][name]
    puts "   📊 Category Results: #{category_stats[:passed]} passed, #{category_stats[:failed]} failed"
    puts
  end
  
  def run_multi_implementation_test(test_case)
    puts "    🧪 #{test_case[:description]}"
    
    implementations = []
    
    # Test with Ruby evaluator
    ruby_result = test_with_ruby_evaluator(test_case[:code])
    implementations << { name: "ruby_evaluator", result: ruby_result }
    
    # Test with Phase 1 bridge (if available)
    if @phase1_bridge
      bridge_result = test_with_phase1_bridge(test_case[:code])
      implementations << { name: "phase1_bridge", result: bridge_result }
    end
    
    # Analyze results
    analyze_test_results(test_case, implementations)
  end
  
  def test_with_ruby_evaluator(code)
    test_with_timeout do
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      result = @evaluator.evaluate(ast)
      { success: true, value: result, implementation: "ruby_evaluator" }
    end
  rescue => e
    { success: false, error: e.message, implementation: "ruby_evaluator" }
  end
  
  def test_with_phase1_bridge(code)
    test_with_timeout do
      result = @phase1_bridge.evaluate(code)
      result
    end
  rescue => e
    { success: false, error: e.message, implementation: "phase1_bridge" }
  end
  
  def test_with_timeout(&block)
    Timeout::timeout(@timeout_seconds) do
      block.call
    end
  rescue Timeout::Error
    { success: false, error: "Test timed out after #{@timeout_seconds} seconds" }
  end
  
  def analyze_test_results(test_case, implementations)
    expected = test_case[:expected]
    expected_to_fail = test_case[:expected_to_fail] || false
    
    all_results = {}
    success_count = 0
    
    implementations.each do |impl|
      result = impl[:result]
      impl_name = impl[:name]
      
      all_results[impl_name] = result
      
      if result[:success]
        if expected_to_fail
          puts "      #{impl_name}: ❓ Unexpected success - #{result[:value]} (expected to fail)"
        elsif expected.nil? || result[:value] == expected
          puts "      #{impl_name}: ✅ #{result[:value]}"
          success_count += 1
        else
          puts "      #{impl_name}: ❌ #{result[:value]} (expected #{expected})"
        end
      else
        if expected_to_fail
          puts "      #{impl_name}: ✅ Failed as expected - #{result[:error]}"
          success_count += 1
        else
          puts "      #{impl_name}: ❌ #{result[:error]}"
        end
      end
    end
    
    # Record results
    test_result = {
      test_case: test_case,
      implementations: all_results,
      success_count: success_count,
      total_implementations: implementations.length
    }
    
    record_test_result(test_case[:description], test_result, test_case[:description])
  end
  
  def record_test_result(test_name, result, description)
    @test_results[:meta][:total_tests] += 1
    
    success = result[:success] || (result.is_a?(Hash) && result[:success_count] && result[:success_count] > 0)
    
    if success
      @test_results[:meta][:passed_tests] += 1
      @test_results[:working_features] << test_name
      
      if @current_category
        @test_results[:feature_categories][@current_category][:passed] += 1
      end
    else
      @test_results[:meta][:failed_tests] += 1
      @test_results[:broken_features] << test_name
      
      # Record critical gaps for core features
      if ["Arithmetic Operations", "String Operations", "Variable Assignment"].include?(@current_category)
        @test_results[:critical_gaps] << {
          feature: test_name,
          category: @current_category,
          error: result[:error] || "Feature not implemented"
        }
      end
      
      if @current_category
        @test_results[:feature_categories][@current_category][:failed] += 1
      end
    end
    
    if @current_category
      @test_results[:feature_categories][@current_category][:tests] << {
        name: test_name,
        description: description,
        result: result,
        success: success
      }
    end
  end
  
  def generate_final_report
    puts "\n" + "=" * 60
    puts "📋 COMPREHENSIVE TEST REPORT"
    puts "=" * 60
    
    meta = @test_results[:meta]
    puts "\n📊 OVERALL STATISTICS:"
    puts "  Total Tests: #{meta[:total_tests]}"
    puts "  Passed: #{meta[:passed_tests]} (#{(meta[:passed_tests] * 100.0 / meta[:total_tests]).round(1)}%)"
    puts "  Failed: #{meta[:failed_tests]} (#{(meta[:failed_tests] * 100.0 / meta[:total_tests]).round(1)}%)"
    
    puts "\n✅ WORKING FEATURES:"
    @test_results[:working_features].each { |feature| puts "  • #{feature}" }
    
    puts "\n❌ BROKEN/MISSING FEATURES:"
    @test_results[:broken_features].each { |feature| puts "  • #{feature}" }
    
    puts "\n🚨 CRITICAL GAPS (Core Language Features):"
    @test_results[:critical_gaps].each do |gap|
      puts "  • #{gap[:feature]} (#{gap[:category]}): #{gap[:error]}"
    end
    
    puts "\n📂 FEATURE CATEGORY BREAKDOWN:"
    @test_results[:feature_categories].each do |name, data|
      total = data[:passed] + data[:failed]
      percentage = total > 0 ? (data[:passed] * 100.0 / total).round(1) : 0
      puts "  #{name}: #{data[:passed]}/#{total} (#{percentage}%) - #{data[:description]}"
    end
    
    if @test_results[:performance_benchmarks].any?
      puts "\n⚡ PERFORMANCE BENCHMARKS:"
      @test_results[:performance_benchmarks].each do |name, data|
        puts "  #{name}:"
        if data[:ruby_evaluator]
          puts "    Ruby: #{data[:ruby_evaluator][:average_time_ms].round(3)}ms/op"
        end
        if data[:phase1_bridge]
          puts "    Bridge: #{data[:phase1_bridge][:average_time_ms].round(3)}ms/op"
        end
      end
    end
    
    if @test_results[:implementation_comparison].any?
      puts "\n🔄 IMPLEMENTATION COMPARISON:"
      matches = @test_results[:implementation_comparison].values.count { |comp| comp[:results_match] }
      total = @test_results[:implementation_comparison].values.length
      puts "  Ruby vs PaTLang Evaluator Agreement: #{matches}/#{total} (#{(matches * 100.0 / total).round(1)}%)"
    end
    
    # Save detailed report to JSON
    File.write('end_to_end_feature_test_report.json', JSON.pretty_generate(@test_results))
    puts "\n💾 Detailed report saved to: end_to_end_feature_test_report.json"
    
    # Generate summary recommendations
    generate_recommendations
  end
  
  def generate_recommendations
    puts "\n" + "=" * 60
    puts "💡 DEVELOPMENT RECOMMENDATIONS"  
    puts "=" * 60
    
    critical_count = @test_results[:critical_gaps].length
    working_percentage = (@test_results[:meta][:passed_tests] * 100.0 / @test_results[:meta][:total_tests]).round(1)
    
    puts "\n🎯 PRIORITY ACTIONS:"
    
    if critical_count > 0
      puts "  1. 🚨 HIGH PRIORITY: Fix #{critical_count} critical gaps in core language features"
      puts "     These are fundamental features that should work but don't."
    end
    
    if working_percentage < 50
      puts "  2. 📈 MEDIUM PRIORITY: Current implementation coverage is #{working_percentage}%"
      puts "     Focus on completing basic language constructs before advanced features."
    end
    
    if @test_results[:implementation_comparison].any?
      mismatches = @test_results[:implementation_comparison].values.count { |comp| !comp[:results_match] }
      if mismatches > 0
        puts "  3. 🔄 CONSISTENCY: #{mismatches} evaluator mismatches found"
        puts "     Ruby and PaTLang evaluators should produce identical results."
      end
    end
    
    puts "\n🏗️ IMPLEMENTATION FOCUS AREAS:"
    
    failed_categories = @test_results[:feature_categories].select { |name, data| data[:failed] > data[:passed] }
    failed_categories.each do |name, data|
      puts "  • #{name}: #{data[:failed]} failing tests need attention"
    end
    
    puts "\n✨ POSITIVE HIGHLIGHTS:"
    working_categories = @test_results[:feature_categories].select { |name, data| data[:passed] > 0 }
    working_categories.each do |name, data|
      if data[:passed] == data[:passed] + data[:failed]  # All tests passed
        puts "  • #{name}: All tests passing ✅"
      elsif data[:passed] > data[:failed]  # More passing than failing
        puts "  • #{name}: Mostly working (#{data[:passed]} passed, #{data[:failed]} failed)"
      end
    end
    
    puts "\n🚀 NEXT STEPS:"
    puts "  1. Review detailed JSON report for specific failure analysis"
    puts "  2. Focus on critical gaps first - these block basic usage"
    puts "  3. Use working features as foundation for building missing ones"
    puts "  4. Re-run this test suite after each major implementation change"
    
    puts "\n" + "=" * 60
  end
  
  def cleanup_test_environment
    if @phase1_bridge
      @phase1_bridge.cleanup
    end
    
    puts "🧹 Test environment cleaned up successfully."
  end
end

# =============================================================================
# MAIN EXECUTION
# =============================================================================

if __FILE__ == $0
  puts "🧪 Starting PaTLang End-to-End Feature Testing Suite..."
  puts "This will systematically test what works vs what should work.\n"
  
  test_suite = EndToEndFeatureTestSuite.new
  test_suite.run_comprehensive_test_suite
  
  puts "\n🎉 End-to-end feature testing complete!"
  puts "Check end_to_end_feature_test_report.json for detailed results."
end