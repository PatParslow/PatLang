#!/usr/bin/env ruby
# Test Analysis Diagnostic Tool
# Analyzes the comprehensive test suite report to extract actual test run and assertion counts

require 'json'

def analyze_test_numbers
  puts "🔍 ANALYZING TEST NUMBERS FROM COMPREHENSIVE REPORT"
  puts "=" * 60
  
  # Load the comprehensive test suite report
  report_path = 'test/COMPREHENSIVE_TEST_SUITE_REPORT.json'
  
  unless File.exist?(report_path)
    puts "❌ Error: #{report_path} not found"
    return
  end
  
  report = JSON.parse(File.read(report_path))
  
  puts "📊 SUMMARY FROM COMPREHENSIVE REPORT:"
  puts "   Report timestamp: #{report['summary']['timestamp']}"
  puts "   Total test files: #{report['summary']['total_files']}"
  puts "   Passed: #{report['summary']['total_passed']}"
  puts "   Failed: #{report['summary']['total_failed']}"
  puts "   Errors: #{report['summary']['total_errors']}"
  puts "   Success rate: #{report['summary']['success_rate']}%"
  puts
  
  # Extract test runs and assertions from individual test outputs
  total_runs = 0
  total_assertions = 0
  successful_extractions = 0
  
  puts "📋 EXTRACTING RUNS AND ASSERTIONS FROM TEST OUTPUTS:"
  puts
  
  report['test_files'].each do |filename, test_data|
    next unless test_data['status'] == 'passed'
    
    output = test_data['output']
    runs = nil
    assertions = nil
    
    # Look for patterns like "29 runs, 117 assertions"
    if output =~ /(\d+)\s+runs?,\s*(\d+)\s+assertions?/i
      runs = $1.to_i
      assertions = $2.to_i
      total_runs += runs
      total_assertions += assertions
      successful_extractions += 1
      
      puts "✅ #{filename}: #{runs} runs, #{assertions} assertions"
    elsif test_data['status'] == 'passed'
      puts "⚠️  #{filename}: No run/assertion data found in output"
    end
  end
  
  puts
  puts "📊 CURRENT TOTALS (from passed tests only):"
  puts "   Total test runs: #{total_runs}"
  puts "   Total assertions: #{total_assertions}"
  puts "   Successful extractions: #{successful_extractions}/#{report['summary']['total_passed']}"
  puts
  
  # Compare with user's reported historical numbers
  puts "🔍 COMPARISON WITH REPORTED HISTORICAL DATA:"
  puts "   Current runs: #{total_runs}"
  puts "   Reported historical runs: ~1000"
  puts "   Current assertions: #{total_assertions}"
  puts "   Reported historical assertions: thousands"
  puts
  puts "   Run reduction: #{total_runs < 1000 ? "CONFIRMED - #{(1000 - total_runs)} fewer runs" : "NO REDUCTION"}"
  puts "   Assertion reduction: #{total_assertions < 1000 ? "CONFIRMED - significantly fewer assertions" : "NO REDUCTION"}"
  puts
  
  # Analyze test file structure
  puts "📁 TEST FILE STRUCTURE ANALYSIS:"
  report['categories'].each do |category, data|
    puts "   #{category}: #{data['test_files'].length} files (#{data['passed']} passed, #{data['failed']} failed, #{data['errors']} errors)"
  end
  puts
  
  # Check for missing categories or test types
  puts "🔍 POTENTIAL MISSING TEST CATEGORIES:"
  all_files_in_test_dir = Dir.glob('test/**/*.rb').select { |f| File.basename(f).start_with?('test_') }
  total_possible_files = all_files_in_test_dir.length
  
  puts "   Total .rb test files in test/ directory: #{total_possible_files}"
  puts "   Files run by comprehensive suite: #{report['summary']['total_files']}"
  puts "   Potentially missing files: #{total_possible_files - report['summary']['total_files']}"
  
  if total_possible_files > report['summary']['total_files']
    missing_files = all_files_in_test_dir - report['test_files'].keys.map { |f| "test/#{f}" }
    puts "   Missing files:"
    missing_files.each { |f| puts "     - #{f}" }
  end
  
  puts
  puts "🎯 DIAGNOSIS:"
  if total_runs < 200 && total_assertions < 2000
    puts "   ✅ CONFIRMED: Dramatic test reduction detected"
    puts "   📉 Current: #{total_runs} runs, #{total_assertions} assertions"
    puts "   📈 Expected (historical): ~1000 runs, thousands of assertions"
    puts "   💡 Likely cause: Switch from comprehensive to focused test runner"
  else
    puts "   ❓ Numbers seem reasonable - need more historical data"
  end
end

# Run analysis
analyze_test_numbers