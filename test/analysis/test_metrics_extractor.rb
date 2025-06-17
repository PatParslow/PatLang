#!/usr/bin/env ruby
require 'json'

puts "=== TEST METRICS EXTRACTION ==="

# Read the comprehensive test report
report_path = 'FIXED_COMPREHENSIVE_TEST_SUITE_REPORT.json'
if File.exist?(report_path)
  data = JSON.parse(File.read(report_path))
  
  total_runs = 0
  total_assertions = 0
  files_with_runs = 0
  files_executed = 0
  
  puts "Analyzing test execution outputs..."
  
  data['categories'].each do |category, category_data|
    puts "\n📁 Category: #{category.upcase}"
    category_runs = 0
    category_assertions = 0
    
    category_data['test_files'].each do |test_file|
      files_executed += 1
      output = test_file['output'] || ""
      
      # Extract runs and assertions from test output
      # Pattern: "X runs, Y assertions, Z failures, W errors, V skips"
      if matches = output.match(/(\d+) runs?, (\d+) assertions?/)
        runs = matches[1].to_i
        assertions = matches[2].to_i
        
        total_runs += runs
        total_assertions += assertions
        category_runs += runs
        category_assertions += assertions
        files_with_runs += 1
        
        puts "  #{test_file['file']}: #{runs} runs, #{assertions} assertions (#{test_file['status']})"
      else
        puts "  #{test_file['file']}: No test metrics found (#{test_file['status']})"
      end
    end
    
    puts "  Category totals: #{category_runs} runs, #{category_assertions} assertions"
  end
  
  puts "\n" + "="*60
  puts "📊 COMPREHENSIVE TEST METRICS SUMMARY"
  puts "="*60
  puts "Files Executed: #{files_executed}"
  puts "Files with Test Runs: #{files_with_runs}"
  puts "Files without Test Runs: #{files_executed - files_with_runs}"
  puts
  puts "TOTAL TEST RUNS: #{total_runs}"
  puts "TOTAL ASSERTIONS: #{total_assertions}"
  puts
  puts "COMPARISON WITH ORIGINAL NUMBERS:"
  puts "  Original reported: 117 runs, 868 assertions"
  puts "  Historical claims: ~1000 runs, thousands of assertions"
  puts "  New enhanced suite: #{total_runs} runs, #{total_assertions} assertions"
  puts
  puts "IMPROVEMENT ANALYSIS:"
  if total_runs > 117
    puts "  ✅ Test runs INCREASED: +#{total_runs - 117} runs (#{((total_runs - 117) / 117.0 * 100).round(1)}% improvement)"
  else
    puts "  ❌ Test runs DECREASED: #{total_runs - 117} runs"
  end
  
  if total_assertions > 868
    puts "  ✅ Assertions INCREASED: +#{total_assertions - 868} assertions (#{((total_assertions - 868) / 868.0 * 100).round(1)}% improvement)"
  else
    puts "  ❌ Assertions DECREASED: #{total_assertions - 868} assertions"
  end
  
  puts
  puts "DISCOVERY IMPROVEMENT:"
  discovery = data["discovery_stats"]
  puts "  Previous discovery: #{discovery['previous_discovery_count']} files"
  puts "  Enhanced discovery: #{discovery['legitimate_test_files']} files"
  puts "  Additional files: +#{discovery['legitimate_test_files'] - discovery['previous_discovery_count']}"
  puts "  Files executed: #{files_executed}"
  puts "  Success rate: #{data['summary']['success_rate']}%"
  
  puts "\n" + "="*60
  puts "🎯 VALIDATION RESULTS"
  puts "="*60
  
  # Determine if the solution achieved its goals
  enhanced_discovery = discovery['legitimate_test_files'] > discovery['previous_discovery_count']
  more_runs = total_runs > 117
  more_assertions = total_assertions > 868
  all_files_executed = files_executed == discovery['legitimate_test_files']
  
  puts "1. Enhanced test discovery: #{enhanced_discovery ? '✅ SUCCESS' : '❌ FAILED'}"
  puts "2. Increased test runs: #{more_runs ? '✅ SUCCESS' : '❌ FAILED'}"
  puts "3. Increased assertions: #{more_assertions ? '✅ SUCCESS' : '❌ FAILED'}"
  puts "4. All discovered files executed: #{all_files_executed ? '✅ SUCCESS' : '❌ FAILED'}"
  
  overall_success = enhanced_discovery && more_runs && more_assertions && all_files_executed
  puts "\n🏆 OVERALL VALIDATION: #{overall_success ? '✅ SUCCESS - Test reduction issue RESOLVED' : '⚠️  PARTIAL SUCCESS - Some issues remain'}"
  
else
  puts "❌ Report file not found: #{report_path}"
end