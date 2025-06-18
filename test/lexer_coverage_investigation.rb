#!/usr/bin/env ruby
# frozen_string_literal: true

# Lexer Coverage Investigation Tool
# Investigates the discrepancy between comprehensive Phase 3 tests and low coverage numbers

require 'simplecov'

# Configure SimpleCov for focused lexer analysis
SimpleCov.start do
  add_filter '/test/'
  add_filter '/bin/'
  add_filter '/tools/'
  add_filter '/docs/'
  add_filter '/examples/'
  
  # Focus specifically on lexer
  add_group "Lexer", "src/lexer.rb"
  
  enable_coverage :branch
  coverage_dir 'test/coverage/lexer_investigation'
  
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
end

puts "🔍 LEXER COVERAGE INVESTIGATION"
puts "=" * 50

# Load the lexer to ensure SimpleCov tracks it
require_relative '../patlang-core/lexer/lexer'
require_relative '../patlang-core/lexer/token'

puts "\n1️⃣ Loading lexer classes..."
puts "   ✅ Lexer class loaded"
puts "   ✅ Token class loaded"

# Run comprehensive lexer tests
lexer_test_files = [
  'test/infrastructure/test_lexer_edge_cases_final.rb',
  'test/infrastructure/test_lexer_comprehensive.rb',
  'test/infrastructure/test_lexer_coverage_enhancement.rb',
  'test/infrastructure/test_lexer_error_recovery.rb'
].select { |file| File.exist?(file) }

puts "\n2️⃣ Found lexer test files:"
lexer_test_files.each { |file| puts "   📄 #{file}" }

# Load and run each test file
test_results = {}
total_tests = 0
total_assertions = 0

lexer_test_files.each do |test_file|
  puts "\n3️⃣ Running #{File.basename(test_file)}..."
  
  begin
    # Load the test file
    load test_file
    
    # Find the test class
    test_class_name = File.basename(test_file, '.rb').split('_').map(&:capitalize).join.gsub('Test', 'Test')
    
    # Try different possible class names
    possible_classes = [
      'TestLexerEdgeCasesFinal',
      'TestLexerComprehensive', 
      'TestLexerCoverageEnhancement',
      'TestLexerErrorRecovery'
    ]
    
    test_class = nil
    possible_classes.each do |class_name|
      begin
        test_class = Object.const_get(class_name)
        break if test_class
      rescue NameError
        next
      end
    end
    
    if test_class
      # Run the tests
      test_methods = test_class.instance_methods.select { |m| m.to_s.start_with?('test_') }
      puts "   🧪 Found #{test_methods.length} test methods"
      
      # Create a test instance and run each method
      test_instance = test_class.new
      method_results = []
      
      test_methods.each do |method_name|
        begin
          start_time = Time.now
          test_instance.send(method_name)
          end_time = Time.now
          method_results << { method: method_name, success: true, time: end_time - start_time }
        rescue => e
          method_results << { method: method_name, success: false, error: e.message }
        end
      end
      
      successes = method_results.count { |r| r[:success] }
      failures = method_results.count { |r| !r[:success] }
      
      test_results[test_file] = {
        class: test_class.name,
        methods: test_methods.length,
        successes: successes,
        failures: failures,
        results: method_results
      }
      
      total_tests += test_methods.length
      
      puts "   ✅ #{successes} passed, ❌ #{failures} failed"
    else
      puts "   ⚠️  Could not find test class in #{test_file}"
    end
    
  rescue => e
    puts "   ❌ Error loading #{test_file}: #{e.message}"
    test_results[test_file] = { error: e.message }
  end
end

puts "\n4️⃣ COVERAGE ANALYSIS SUMMARY"
puts "=" * 30

# Generate final coverage report
SimpleCov.result

coverage_data = SimpleCov.result
lexer_coverage = coverage_data.source_files.find { |f| f.filename.end_with?('src/lexer.rb') }

if lexer_coverage
  puts "\n📊 LEXER COVERAGE RESULTS:"
  puts "   📄 File: #{lexer_coverage.filename}"
  puts "   📏 Total Lines: #{lexer_coverage.lines.count}"
  puts "   ✅ Covered Lines: #{lexer_coverage.covered_lines.count}"
  puts "   ❌ Missed Lines: #{lexer_coverage.missed_lines.count}"
  puts "   📈 Line Coverage: #{lexer_coverage.covered_percent.round(2)}%"
  
  if lexer_coverage.branches
    covered_branches = lexer_coverage.branches.values.count { |hits| hits > 0 }
    total_branches = lexer_coverage.branches.count
    branch_coverage = total_branches > 0 ? (covered_branches.to_f / total_branches * 100).round(2) : 0
    
    puts "   🌳 Total Branches: #{total_branches}"
    puts "   ✅ Covered Branches: #{covered_branches}"
    puts "   ❌ Missed Branches: #{total_branches - covered_branches}"
    puts "   📈 Branch Coverage: #{branch_coverage}%"
  end
  
  # Show first 10 missed lines for analysis
  if lexer_coverage.missed_lines.any?
    puts "\n❌ FIRST 10 MISSED LINES:"
    lexer_coverage.missed_lines.first(10).each do |line_num|
      puts "   Line #{line_num}: (check src/lexer.rb)"
    end
  end
else
  puts "   ⚠️  No lexer coverage data found"
end

puts "\n5️⃣ TEST EXECUTION SUMMARY"
puts "=" * 30
puts "   📄 Test Files Processed: #{lexer_test_files.length}"
puts "   🧪 Total Test Methods: #{total_tests}"

test_results.each do |file, results|
  next if results[:error]
  puts "   📄 #{File.basename(file)}: #{results[:successes]}/#{results[:methods]} passed"
end

puts "\n6️⃣ KEY FINDINGS"
puts "=" * 20

if lexer_coverage && lexer_coverage.covered_percent < 70
  puts "   🚨 ISSUE IDENTIFIED: Low coverage despite comprehensive tests"
  puts "   🔍 INVESTIGATION NEEDED:"
  puts "     - Check if all lexer methods are being called by tests"
  puts "     - Verify test execution is actually running the lexer code"
  puts "     - Examine missed lines to see what functionality is untested"
  puts "     - Consider if coverage tool is properly configured"
elsif lexer_coverage && lexer_coverage.covered_percent >= 95
  puts "   ✅ COVERAGE LOOKS GOOD: Tests appear to be working correctly"
  puts "   🔍 CHECK: Original coverage report may be outdated"
else
  puts "   ⚠️  MODERATE COVERAGE: Some improvement possible"
end

puts "\n📊 Detailed HTML report generated at: test/coverage/lexer_investigation/index.html"
puts "🔍 Investigation complete!"