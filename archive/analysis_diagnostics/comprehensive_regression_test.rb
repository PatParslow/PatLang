#!/usr/bin/env ruby

require_relative 'src/patlang'
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

puts "🎯 COMPREHENSIVE REGRESSION TESTING & PRIORITY ANALYSIS"
puts "=" * 70

# Track test results
results = {
  critical_passed: 0,
  critical_failed: 0,
  high_passed: 0,
  high_failed: 0,
  medium_passed: 0,
  medium_failed: 0,
  low_passed: 0,
  low_failed: 0,
  regressions: [],
  performance_issues: []
}

def test_case(name, priority, &block)
  print "#{priority.upcase.ljust(8)} | #{name.ljust(50)} | "
  start_time = Time.now
  
  begin
    result = block.call
    end_time = Time.now
    duration = ((end_time - start_time) * 1000).round(3)
    
    puts "✅ PASS (#{duration}ms)"
    return { status: :pass, duration: duration, priority: priority }
  rescue => e
    end_time = Time.now
    duration = ((end_time - start_time) * 1000).round(3)
    puts "❌ FAIL (#{duration}ms) - #{e.message}"
    return { status: :fail, duration: duration, priority: priority, error: e.message }
  end
end

puts "\n🔧 CORE FUNCTIONALITY REGRESSION TESTS"
puts "-" * 70

# CRITICAL: Basic arithmetic operations that must never fail
result = test_case("Basic integer evaluation", "critical") do
  result = Patlang.evaluate("42")
  raise "Expected 42.0, got #{result}" unless result == 42.0
  result
end
results[:critical_passed] += 1 if result[:status] == :pass
results[:critical_failed] += 1 if result[:status] == :fail
results[:regressions] << result if result[:status] == :fail

result = test_case("Basic addition", "critical") do
  result = Patlang.evaluate("10 + 5")
  raise "Expected 15.0, got #{result}" unless result == 15.0
  result
end
results[:critical_passed] += 1 if result[:status] == :pass
results[:critical_failed] += 1 if result[:status] == :fail
results[:regressions] << result if result[:status] == :fail

result = test_case("Expression precedence", "critical") do
  result = Patlang.evaluate("10 + 5 * 2")
  raise "Expected 20.0, got #{result}" unless result == 20.0
  result
end
results[:critical_passed] += 1 if result[:status] == :pass
results[:critical_failed] += 1 if result[:status] == :fail
results[:regressions] << result if result[:status] == :fail

result = test_case("Complex parentheses", "critical") do
  result = Patlang.evaluate("(1 + 2) * (3 + 4)")
  raise "Expected 21.0, got #{result}" unless result == 21.0
  result
end
results[:critical_passed] += 1 if result[:status] == :pass
results[:critical_failed] += 1 if result[:status] == :fail
results[:regressions] << result if result[:status] == :fail

# HIGH: String operations essential for language functionality
result = test_case("Basic string concatenation", "high") do
  result = Patlang.evaluate('"hello" + " world"')
  raise "Expected 'hello world', got #{result}" unless result == "hello world"
  result
end
results[:high_passed] += 1 if result[:status] == :pass
results[:high_failed] += 1 if result[:status] == :fail
results[:regressions] << result if result[:status] == :fail

result = test_case("String with single quotes", "high") do
  result = Patlang.evaluate("'test' + ' string'")
  raise "Expected 'test string', got #{result}" unless result == "test string"
  result
end
results[:high_passed] += 1 if result[:status] == :pass
results[:high_failed] += 1 if result[:status] == :fail
results[:regressions] << result if result[:status] == :fail

# MEDIUM: Component integration tests
result = test_case("Lexer instantiation", "medium") do
  lexer = Lexer.new("test")
  raise "Lexer failed to initialize" unless lexer
  "Lexer OK"
end
results[:medium_passed] += 1 if result[:status] == :pass
results[:medium_failed] += 1 if result[:status] == :fail

result = test_case("Parser instantiation", "medium") do
  lexer = Lexer.new("test")
  parser = Parser.new(lexer)
  raise "Parser failed to initialize" unless parser
  "Parser OK"
end
results[:medium_passed] += 1 if result[:status] == :pass
results[:medium_failed] += 1 if result[:status] == :fail

result = test_case("Evaluator instantiation", "medium") do
  evaluator = Evaluator.new
  raise "Evaluator failed to initialize" unless evaluator
  "Evaluator OK"
end
results[:medium_passed] += 1 if result[:status] == :pass
results[:medium_failed] += 1 if result[:status] == :fail

# LOW: Advanced arithmetic
result = test_case("Division operation", "low") do
  result = Patlang.evaluate("10 / 2")
  raise "Expected 5.0, got #{result}" unless result == 5.0
  result
end
results[:low_passed] += 1 if result[:status] == :pass
results[:low_failed] += 1 if result[:status] == :fail

result = test_case("Subtraction operation", "low") do
  result = Patlang.evaluate("10 - 3")
  raise "Expected 7.0, got #{result}" unless result == 7.0
  result
end
results[:low_passed] += 1 if result[:status] == :pass
results[:low_failed] += 1 if result[:status] == :fail

puts "\n📊 PERFORMANCE REGRESSION TESTS"
puts "-" * 70

# Performance benchmarks from task requirements
performance_tests = [
  { expr: "42", target: 1.0, name: "Simple arithmetic" },
  { expr: "10 + 5 * 2", target: 1.0, name: "Expression precedence" },
  { expr: '"hello" + " world"', target: 1.0, name: "String concatenation" },
  { expr: "(1 + 2) * (3 + 4)", target: 1.0, name: "Complex expression" }
]

performance_tests.each do |test|
  result = test_case("Performance: #{test[:name]}", "high") do
    start_time = Time.now
    result = Patlang.evaluate(test[:expr])
    end_time = Time.now
    duration_ms = (end_time - start_time) * 1000
    
    if duration_ms > test[:target]
      results[:performance_issues] << {
        expression: test[:expr],
        duration: duration_ms,
        target: test[:target],
        name: test[:name]
      }
      raise "Performance regression: #{duration_ms}ms > #{test[:target]}ms target"
    end
    
    result
  end
  results[:high_passed] += 1 if result[:status] == :pass
  results[:high_failed] += 1 if result[:status] == :fail
end

puts "\n🏆 REGRESSION TEST SUMMARY"
puts "=" * 70
puts "CRITICAL TESTS: #{results[:critical_passed]} PASS, #{results[:critical_failed]} FAIL"
puts "HIGH TESTS:     #{results[:high_passed]} PASS, #{results[:high_failed]} FAIL"
puts "MEDIUM TESTS:   #{results[:medium_passed]} PASS, #{results[:medium_failed]} FAIL"
puts "LOW TESTS:      #{results[:low_passed]} PASS, #{results[:low_failed]} FAIL"

total_tests = results[:critical_passed] + results[:critical_failed] + 
              results[:high_passed] + results[:high_failed] +
              results[:medium_passed] + results[:medium_failed] +
              results[:low_passed] + results[:low_failed]

total_passed = results[:critical_passed] + results[:high_passed] + 
               results[:medium_passed] + results[:low_passed]

success_rate = ((total_passed.to_f / total_tests) * 100).round(1)

puts "\nOVERALL SUCCESS RATE: #{success_rate}%"

puts "\n🚨 PRIORITY ISSUES ANALYSIS"
puts "=" * 70

if results[:critical_failed] > 0
  puts "🔴 BLOCKING CRITICAL ISSUES (#{results[:critical_failed]}):"
  results[:regressions].select { |r| r[:priority] == "critical" }.each_with_index do |reg, i|
    puts "  #{i+1}. CRITICAL: #{reg[:error]}"
  end
  puts "  ACTION REQUIRED: Must fix before any further development"
end

if results[:high_failed] > 0
  puts "🟠 HIGH PRIORITY ISSUES (#{results[:high_failed]}):"
  results[:regressions].select { |r| r[:priority] == "high" }.each_with_index do |reg, i|
    puts "  #{i+1}. HIGH: #{reg[:error]}"
  end
  puts "  ACTION REQUIRED: Should fix in next sprint"
end

if results[:performance_issues].any?
  puts "⚡ PERFORMANCE REGRESSIONS (#{results[:performance_issues].length}):"
  results[:performance_issues].each_with_index do |perf, i|
    puts "  #{i+1}. #{perf[:name]}: #{perf[:duration].round(3)}ms (target: #{perf[:target]}ms)"
  end
end

puts "\n📋 RECOMMENDATIONS"
puts "=" * 70

if results[:critical_failed] == 0
  puts "✅ Core functionality is stable - no critical regressions"
else
  puts "🚨 IMMEDIATE ACTION REQUIRED: #{results[:critical_failed]} critical failures block development"
end

if success_rate >= 90
  puts "✅ High overall success rate indicates stable codebase"
elsif success_rate >= 80
  puts "⚠️  Moderate success rate - monitor closely"
else
  puts "🚨 Low success rate indicates significant instability"
end

puts "\n🎯 PRIORITY MATRIX FOR REMAINING WORK"
puts "-" * 70
puts "CRITICAL (Must Fix): #{results[:critical_failed]} issues"
puts "HIGH (Should Fix):   #{results[:high_failed]} issues"  
puts "MEDIUM (Could Fix):  #{results[:medium_failed]} issues"
puts "LOW (Nice to Fix):   #{results[:low_failed]} issues"

puts "\nCore language functionality regression testing complete!"
exit(results[:critical_failed] > 0 ? 1 : 0)