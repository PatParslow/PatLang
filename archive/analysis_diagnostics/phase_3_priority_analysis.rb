#!/usr/bin/env ruby

puts "🎯 PHASE 3 PRIORITY ANALYSIS: HIGH-IMPACT OPPORTUNITIES"
puts "=" * 70

# Get detailed test output for specific error analysis
test_output = `ruby test/run_all_tests.rb 2>&1`

puts "\n🔍 ANALYZING SPECIFIC ERROR PATTERNS FOR MAXIMUM IMPACT..."

# Priority 1: ArgumentError with unknown keywords (Reasoning Integration)
puts "\n🥇 PRIORITY 1: REASONING INTEGRATION - KEYWORD ERRORS"
puts "-" * 60

postcondition_errors = test_output.scan(/.*unknown keyword.*:postcondition.*/)
puts "Postcondition keyword errors: #{postcondition_errors.length}"

context_errors = test_output.scan(/.*unknown keywords.*:description.*:strategies.*:subgoals.*:context.*/)
puts "Goal definition keyword errors: #{context_errors.length}"

# Extract specific test cases
goal_parsing_failures = test_output.split("\n").select { |line| 
  line.match?(/goal.*\{/) || line.match?(/postcondition:/) || line.match?(/pursue/)
}.first(5)

puts "\nSpecific Goal Parsing Issues:"
goal_parsing_failures.each { |issue| puts "  • #{issue.strip}" }

# Priority 2: Object Model - Missing Object Class
puts "\n🥈 PRIORITY 2: OBJECT MODEL - MISSING OBJECT CLASS"
puts "-" * 60

object_undefined_errors = test_output.scan(/.*Undefined variable: Object.*/)
puts "Object class undefined errors: #{object_undefined_errors.length}"

# Extract Object-related test failures
object_issues = test_output.split("\n").select { |line|
  line.match?(/Object\.new/) || line.match?(/Undefined variable: Object/)
}.first(5)

puts "\nSpecific Object Model Issues:"
object_issues.each { |issue| puts "  • #{issue.strip}" }

# Priority 3: NoMethodError on nil objects (Cross-Paradigm)
puts "\n🥉 PRIORITY 3: CROSS-PARADIGM - NIL OBJECT ERRORS"
puts "-" * 60

nil_method_errors = test_output.scan(/.*undefined method.*for nil.*/)
puts "Nil object method errors: #{nil_method_errors.length}"

# Extract specific nil errors
nil_issues = test_output.split("\n").select { |line|
  line.match?(/undefined method.*for nil/) || line.match?(/NoMethodError.*nil/)
}.first(5)

puts "\nSpecific Nil Object Issues:"
nil_issues.each { |issue| puts "  • #{issue.strip}" }

# Cascade Analysis: Identify errors that likely cause other errors
puts "\n🌊 CASCADE OPPORTUNITY ANALYSIS"
puts "-" * 60

puts "High-Impact Cascade Candidates:"

# Object class missing likely causes multiple object-related failures
object_cascade_potential = test_output.scan(/Object/).length
puts "1. Object class implementation: #{object_cascade_potential} potential fixes"

# Goal parsing issues likely affect all reasoning features
goal_cascade_potential = test_output.scan(/goal|postcondition|pursue/).length
puts "2. Goal keyword parsing: #{goal_cascade_potential} potential fixes"

# Event system integration issues
event_cascade_potential = test_output.scan(/event|Event/).length
puts "3. Event system integration: #{event_cascade_potential} potential fixes"

# Implementation Complexity Analysis
puts "\n⚙️ IMPLEMENTATION COMPLEXITY ANALYSIS"
puts "-" * 60

puts "Easy Wins (Low complexity, High impact):"
puts "1. Add basic Object class definition"
puts "2. Fix postcondition keyword recognition in goal parser"
puts "3. Add missing nil checks in cross-paradigm coordination"

puts "\nMedium Effort (Medium complexity, High impact):"
puts "1. Implement goal definition keyword parsing"
puts "2. Fix event system nil object handling"
puts "3. Complete basic facts database integration"

puts "\nHigh Effort (High complexity, Medium impact):"
puts "1. Advanced goal strategies (marked as RED phase)"
puts "2. Performance optimization features"
puts "3. Enterprise-scale processing features"

# File Impact Analysis
puts "\n📁 FILE IMPACT ANALYSIS"
puts "-" * 60

# Look for files mentioned in error traces
file_mentions = {}
test_output.scan(/([a-zA-Z_\/]+\.rb):\d+/) do |match|
  file = match[0]
  file_mentions[file] = (file_mentions[file] || 0) + 1
end

puts "Files with highest error density:"
file_mentions.sort_by { |k, v| -v }.first(8).each do |file, count|
  puts "  • #{file}: #{count} errors"
end

# NotImplementedError Deep Analysis
puts "\n🚧 NOTIMPLEMENTEDERROR IMPLEMENTATION STRATEGY"
puts "-" * 60

# Separate RED phase (future) from implementable stubs
red_phase_errors = test_output.scan(/NotImplementedError.*RED phase.*/).length
implementable_errors = test_output.scan(/NotImplementedError/).length - red_phase_errors

puts "RED Phase (Future Development): #{red_phase_errors} errors"
puts "Potentially Implementable: #{implementable_errors} errors"

# Look for specific implementable NotImplementedError cases
implementable_cases = test_output.split("\n").select { |line|
  line.match?(/NotImplementedError/) && !line.match?(/RED phase/)
}.first(5)

puts "\nImplementable NotImplementedError Cases:"
implementable_cases.each { |case_line| puts "  • #{case_line.strip}" }

puts "\n✅ Priority Analysis Complete"
puts "📋 Ready for Phase 3 Strategy Formulation"