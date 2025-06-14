#!/usr/bin/env ruby

# Test Error Analysis Runner
# Processes the actual test output to generate comprehensive analysis

require 'json'
require_relative 'comprehensive_test_error_analysis'

# Read the actual test output
test_output = File.read('test_output_full.txt')

# Create analyzer and process the output
analyzer = TestErrorAnalyzer.new
analyzer.analyze_test_output(test_output)

# Generate and display the report
analyzer.print_summary
report = analyzer.save_report('FINAL_COMPREHENSIVE_TEST_ERROR_ANALYSIS.json')

puts "\n" + "="*80
puts "🎯 KEY FINDINGS SUMMARY:"
puts "="*80

critical_errors = report[:prioritized_fixes].select { |fix| fix[:severity] == 'CRITICAL' }
high_errors = report[:prioritized_fixes].select { |fix| fix[:severity] == 'HIGH' }

puts "\n🚨 CRITICAL ISSUES (#{critical_errors.length}):"
critical_errors.each do |error|
  puts "   • #{error[:category]} (#{error[:count]} failures)"
  puts "     Root Cause: #{error[:root_cause]}"
end

puts "\n⚠️  HIGH PRIORITY ISSUES (#{high_errors.length}):"
high_errors.each do |error|
  puts "   • #{error[:category]} (#{error[:count]} failures)"
  puts "     Root Cause: #{error[:root_cause]}"
end

puts "\n🔧 IMMEDIATE ACTION REQUIRED:"
puts "   1. Fix Token Resolver return statement (CRITICAL)"
puts "   2. Implement missing methods (HIGH)"
puts "   3. Fix constructor signatures (HIGH)"

puts "\n📊 IMPACT ANALYSIS:"
puts "   Total Test Failures: #{report[:summary][:total_failures] + report[:summary][:total_errors]}"
puts "   Success Rate: #{report[:summary][:success_rate]}%"
if report[:component_impact] && !report[:component_impact].empty?
  puts "   Most Affected Component: #{report[:component_impact].first[0]} (#{report[:component_impact].first[1]} errors)"
else
  puts "   Most Affected Component: Data not available"
end

puts "\n" + "="*80
puts "Analysis complete. See FINAL_COMPREHENSIVE_TEST_ERROR_ANALYSIS.json for full details."
puts "="*80