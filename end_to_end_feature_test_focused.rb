#!/usr/bin/env ruby

# =============================================================================
# FOCUSED END-TO-END PATLANG FEATURE TESTING SUITE
# =============================================================================
# 
# A focused version that quickly tests core features and generates a report
# showing what actually works vs what should work in PaTLang.
#
# =============================================================================

require 'json'
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

class FocusedFeatureTestSuite
  def initialize
    @test_results = {
      meta: {
        test_suite_version: "1.0.0-focused",
        timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
        total_tests: 0,
        passed_tests: 0,
        failed_tests: 0
      },
      feature_summary: {},
      critical_findings: [],
      working_features: [],
      broken_features: []
    }
    
    @timeout_seconds = 5
    puts "🧪 FOCUSED PATLANG FEATURE TEST SUITE"
    puts "=" * 50
  end
  
  def run_focused_test_suite
    puts "🚀 Running focused feature tests...\n"
    
    # Initialize components
    initialize_components
    
    # Run core tests quickly
    test_arithmetic_core
    test_string_core
    test_control_flow_core
    test_functions_core
    test_natural_language_core
    test_advanced_features_core
    
    # Generate report
    generate_focused_report
  end
  
  private
  
  def initialize_components
    puts "🔧 Initializing components..."
    
    if CORE_COMPONENTS_AVAILABLE
      @evaluator = Evaluator.new
      puts "  ✅ Ruby evaluator: Available"
    else
      @evaluator = nil
      puts "  ❌ Ruby evaluator: Not available"
    end
    
    if PHASE1_BRIDGE_AVAILABLE
      begin
        @phase1_bridge = PaTLangPhase1Bridge.new
        puts "  ✅ Phase 1 bridge: Available"
      rescue => e
        @phase1_bridge = nil
        puts "  ❌ Phase 1 bridge: Failed (#{e.message})"
      end
    else
      @phase1_bridge = nil
      puts "  ❌ Phase 1 bridge: Not available"
    end
    
    puts
  end
  
  def test_arithmetic_core
    test_feature("Arithmetic Operations") do
      tests = [
        { code: "42", expected: 42, desc: "Integer literal" },
        { code: "2 + 3", expected: 5, desc: "Addition" },
        { code: "2 * 3 + 1", expected: 7, desc: "Precedence" },
        { code: "(2 + 3) * 4", expected: 20, desc: "Parentheses" }
      ]
      
      test_multiple(tests)
    end
  end
  
  def test_string_core
    test_feature("String Operations") do
      tests = [
        { code: '"Hello"', expected: "Hello", desc: "String literal" },
        { code: '"Hello" + " World"', expected: "Hello World", desc: "Concatenation" }
      ]
      
      test_multiple(tests)
    end
  end
  
  def test_control_flow_core
    test_feature("Control Flow") do
      tests = [
        { code: "if true then 1 else 2 end", expected: 1, desc: "If-then-else" },
        { code: "if 5 > 3 then \"yes\" else \"no\" end", expected: "yes", desc: "Comparison" }
      ]
      
      test_multiple(tests)
    end
  end
  
  def test_functions_core
    test_feature("Function Definitions") do
      tests = [
        { 
          code: "make a function called test { return 42 }\ncall test", 
          expected: 42, 
          desc: "Simple function",
          expected_status: :should_work_but_might_not
        },
        { 
          code: "make a function called add takes: x, y { return x + y }\ncall add with 2, 3", 
          expected: 5, 
          desc: "Function with params",
          expected_status: :should_work_but_might_not
        }
      ]
      
      test_multiple(tests)
    end
  end
  
  def test_natural_language_core
    test_feature("Natural Language Syntax") do
      tests = [
        { 
          code: "create a variable called x with value 5", 
          expected: nil, 
          desc: "Natural variable creation",
          expected_status: :expected_to_fail
        },
        { 
          code: "when temperature changes: print \"updated\"", 
          expected: nil, 
          desc: "Natural event syntax",
          expected_status: :expected_to_fail
        }
      ]
      
      test_multiple(tests)
    end
  end
  
  def test_advanced_features_core
    test_feature("Advanced Features") do
      tests = [
        { 
          code: "goal solve(x) { precondition: x > 0 }", 
          expected: nil, 
          desc: "Goal-oriented syntax",
          expected_status: :expected_to_fail
        },
        { 
          code: "fact parent(tom, bob)", 
          expected: nil, 
          desc: "Logic programming",
          expected_status: :expected_to_fail
        }
      ]
      
      test_multiple(tests)
    end
  end
  
  def test_feature(name, &block)
    puts "📂 #{name}"
    
    @current_feature = name
    @test_results[:feature_summary][name] = {
      passed: 0,
      failed: 0,
      tests: []
    }
    
    block.call
    
    summary = @test_results[:feature_summary][name]
    puts "   📊 #{summary[:passed]} passed, #{summary[:failed]} failed"
    puts
  end
  
  def test_multiple(tests)
    tests.each do |test|
      run_single_test(test)
    end
  end
  
  def run_single_test(test)
    puts "    🧪 #{test[:desc]}"
    
    @test_results[:meta][:total_tests] += 1
    
    # Test with Ruby evaluator
    ruby_result = test_with_evaluator(test[:code], @evaluator, "ruby")
    
    # Test with Phase 1 bridge if available
    bridge_result = @phase1_bridge ? test_with_bridge(test[:code]) : nil
    
    # Analyze results
    analyze_test_result(test, ruby_result, bridge_result)
  end
  
  def test_with_evaluator(code, evaluator, impl_name)
    return { success: false, error: "Evaluator not available", impl: impl_name } unless evaluator
    
    Timeout::timeout(@timeout_seconds) do
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      result = evaluator.evaluate(ast)
      { success: true, value: result, impl: impl_name }
    end
  rescue Timeout::Error
    { success: false, error: "Timeout", impl: impl_name }
  rescue => e
    { success: false, error: e.message, impl: impl_name }
  end
  
  def test_with_bridge(code)
    Timeout::timeout(@timeout_seconds) do
      result = @phase1_bridge.evaluate(code, prefer_patlang: true)
      result.merge(impl: "phase1_bridge")
    end
  rescue Timeout::Error
    { success: false, error: "Timeout", impl: "phase1_bridge" }
  rescue => e
    { success: false, error: e.message, impl: "phase1_bridge" }
  end
  
  def analyze_test_result(test, ruby_result, bridge_result)
    expected = test[:expected]
    expected_status = test[:expected_status] || :should_work
    
    # Check Ruby evaluator result
    ruby_success = evaluate_result_success(ruby_result, expected, expected_status)
    bridge_success = bridge_result ? evaluate_result_success(bridge_result, expected, expected_status) : nil
    
    overall_success = ruby_success || (bridge_success == true)
    
    # Display results
    display_test_result(ruby_result, "Ruby", ruby_success, expected_status)
    if bridge_result
      display_test_result(bridge_result, "Bridge", bridge_success, expected_status)
    end
    
    # Record results
    record_test_result(test[:desc], overall_success, ruby_result, bridge_result)
    
    # Check for critical findings
    if expected_status == :should_work && !overall_success
      @test_results[:critical_findings] << {
        test: test[:desc],
        feature: @current_feature,
        issue: "Core feature not working",
        ruby_error: ruby_result[:error],
        bridge_error: bridge_result&.[](:error)
      }
    end
  end
  
  def evaluate_result_success(result, expected, expected_status)
    case expected_status
    when :should_work
      result[:success] && (expected.nil? || result[:value] == expected)
    when :should_work_but_might_not
      result[:success] && (expected.nil? || result[:value] == expected)
    when :expected_to_fail
      !result[:success]
    else
      false
    end
  end
  
  def display_test_result(result, impl_name, success, expected_status)
    if success
      case expected_status
      when :expected_to_fail
        puts "      #{impl_name}: ✅ Failed as expected"
      else
        puts "      #{impl_name}: ✅ #{result[:value]}"
      end
    else
      case expected_status
      when :expected_to_fail
        puts "      #{impl_name}: ❓ Should have failed but succeeded: #{result[:value]}"
      else
        puts "      #{impl_name}: ❌ #{result[:error] || 'Unexpected result'}"
      end
    end
  end
  
  def record_test_result(test_name, success, ruby_result, bridge_result)
    if success
      @test_results[:meta][:passed_tests] += 1
      @test_results[:working_features] << "#{@current_feature}: #{test_name}"
      @test_results[:feature_summary][@current_feature][:passed] += 1
    else
      @test_results[:meta][:failed_tests] += 1
      @test_results[:broken_features] << "#{@current_feature}: #{test_name}"
      @test_results[:feature_summary][@current_feature][:failed] += 1
    end
    
    @test_results[:feature_summary][@current_feature][:tests] << {
      name: test_name,
      success: success,
      ruby_result: ruby_result,
      bridge_result: bridge_result
    }
  end
  
  def generate_focused_report
    puts "\n" + "=" * 50
    puts "📋 FOCUSED TEST REPORT"
    puts "=" * 50
    
    meta = @test_results[:meta]
    puts "\n📊 OVERALL RESULTS:"
    puts "  Total Tests: #{meta[:total_tests]}"
    puts "  Passed: #{meta[:passed_tests]} (#{(meta[:passed_tests] * 100.0 / meta[:total_tests]).round(1)}%)"
    puts "  Failed: #{meta[:failed_tests]} (#{(meta[:failed_tests] * 100.0 / meta[:total_tests]).round(1)}%)"
    
    puts "\n📂 FEATURE BREAKDOWN:"
    @test_results[:feature_summary].each do |feature, data|
      total = data[:passed] + data[:failed]
      percentage = total > 0 ? (data[:passed] * 100.0 / total).round(1) : 0
      status = percentage == 100 ? "✅" : percentage >= 50 ? "⚠️" : "❌"
      puts "  #{status} #{feature}: #{data[:passed]}/#{total} (#{percentage}%)"
    end
    
    puts "\n✅ WORKING FEATURES:"
    @test_results[:working_features].each { |feature| puts "  • #{feature}" }
    
    puts "\n❌ BROKEN FEATURES:"
    @test_results[:broken_features].each { |feature| puts "  • #{feature}" }
    
    if @test_results[:critical_findings].any?
      puts "\n🚨 CRITICAL FINDINGS:"
      @test_results[:critical_findings].each do |finding|
        puts "  • #{finding[:feature]}: #{finding[:test]}"
        puts "    Issue: #{finding[:issue]}"
        puts "    Ruby Error: #{finding[:ruby_error]}" if finding[:ruby_error]
        puts "    Bridge Error: #{finding[:bridge_error]}" if finding[:bridge_error]
      end
    end
    
    puts "\n💡 SUMMARY ASSESSMENT:"
    
    working_percentage = (meta[:passed_tests] * 100.0 / meta[:total_tests]).round(1)
    
    if working_percentage >= 80
      puts "  🎉 EXCELLENT: #{working_percentage}% of tested features are working!"
      puts "  PaTLang implementation is in good shape for basic usage."
    elsif working_percentage >= 60
      puts "  👍 GOOD: #{working_percentage}% of tested features are working."
      puts "  Core functionality exists but some gaps remain."
    elsif working_percentage >= 40
      puts "  ⚠️  PARTIAL: #{working_percentage}% of tested features are working."
      puts "  Basic features work but significant gaps exist."
    else
      puts "  🚨 CRITICAL: Only #{working_percentage}% of tested features are working."
      puts "  Major implementation gaps prevent practical usage."
    end
    
    # Key findings
    puts "\n🔍 KEY FINDINGS:"
    
    arithmetic_working = @test_results[:feature_summary]["Arithmetic Operations"][:passed] > 0
    strings_working = @test_results[:feature_summary]["String Operations"][:passed] > 0
    control_working = @test_results[:feature_summary]["Control Flow"][:passed] > 0
    functions_working = @test_results[:feature_summary]["Function Definitions"][:passed] > 0
    
    puts "  • Basic arithmetic: #{arithmetic_working ? '✅ Working' : '❌ Broken'}"
    puts "  • String handling: #{strings_working ? '✅ Working' : '❌ Broken'}"
    puts "  • Control flow: #{control_working ? '✅ Working' : '❌ Broken'}"
    puts "  • Function definitions: #{functions_working ? '✅ Working' : '❌ Not implemented'}"
    
    # Component availability
    puts "\n🔧 COMPONENT STATUS:"
    puts "  • Ruby Evaluator: #{@evaluator ? '✅ Available' : '❌ Missing'}"
    puts "  • Phase 1 Bridge: #{@phase1_bridge ? '✅ Available' : '❌ Missing'}"
    
    # Save detailed report
    File.write('focused_feature_test_report.json', JSON.pretty_generate(@test_results))
    puts "\n💾 Detailed report saved to: focused_feature_test_report.json"
    
    puts "\n" + "=" * 50
  end
end

# =============================================================================
# MAIN EXECUTION
# =============================================================================

if __FILE__ == $0
  puts "🧪 Starting Focused PaTLang Feature Testing..."
  
  test_suite = FocusedFeatureTestSuite.new
  test_suite.run_focused_test_suite
  
  puts "\n🎉 Focused feature testing complete!"
  puts "This provides a quick assessment of what actually works in PaTLang."
end