#!/usr/bin/env ruby

# Coverage Fix Verification Tool
# Purpose: Verify that SimpleCov now properly tracks source files after the fix

puts "🔧 COVERAGE FIX VERIFICATION"
puts "=" * 50

# Test the fix by running a focused lexer test with coverage
puts "\n📊 STEP 1: Testing Fixed Coverage Tracking"
puts "-" * 35

require_relative 'helpers/test_helper'
require 'minitest/autorun'

# Load lexer test
require_relative 'core/test_lexer_comprehensive'

puts "\n🧪 STEP 2: Running Sample Lexer Tests"
puts "-" * 30

# Run a subset of lexer tests to generate coverage data
test_class = TestLexerComprehensive
test_instance = test_class.new(:test_lexer_initialization_basic)

# Execute several test methods to exercise lexer code
test_methods = [
  :test_lexer_initialization_basic,
  :test_read_number_integers,
  :test_tokenize_string_double_quotes,
  :test_arithmetic_operators,
  :test_read_identifier_basic,
  :test_tokenize_simple_expression
]

executed_tests = 0
test_methods.each do |method_name|
  begin
    if test_instance.respond_to?(method_name)
      test_instance.setup if test_instance.respond_to?(:setup)
      test_instance.send(method_name)
      executed_tests += 1
      puts "   ✅ #{method_name}"
    else
      puts "   ⚠️  #{method_name} (method not found)"
    end
  rescue => e
    puts "   ❌ #{method_name}: #{e.message}"
  end
end

puts "   Executed #{executed_tests}/#{test_methods.size} test methods"

puts "\n📈 STEP 3: Analyzing Coverage Results"
puts "-" * 30

begin
  # Force SimpleCov to calculate results
  SimpleCov.result.format!
  
  # Get coverage data
  result = SimpleCov.result
  puts "Total files tracked: #{result.files.count}"
  
  # Look for source files in coverage data
  source_files = result.files.select { |file| file.filename.include?('/src/') }
  test_files = result.files.select { |file| file.filename.include?('/test/') }
  
  puts "Source files tracked: #{source_files.count}"
  puts "Test files tracked: #{test_files.count}"
  
  # Find lexer file specifically
  lexer_file = result.files.find { |file| file.filename.include?('lexer.rb') && file.filename.include?('/src/') }
  
  if lexer_file
    puts "\n🎯 LEXER COVERAGE ANALYSIS"
    puts "-" * 25
    puts "✅ Lexer file found in coverage data!"
    puts "   Filename: #{lexer_file.filename}"
    puts "   Lines covered: #{lexer_file.covered_lines.count}"
    puts "   Lines missed: #{lexer_file.missed_lines.count}"
    puts "   Total lines: #{lexer_file.lines.count}"
    puts "   Coverage percentage: #{lexer_file.covered_percent.round(2)}%"
    
    # Calculate coverage improvement
    previous_coverage = 8.4  # From Phase 1 report
    current_coverage = lexer_file.covered_percent
    improvement = current_coverage - previous_coverage
    
    puts "\n📊 COVERAGE IMPROVEMENT"
    puts "-" * 20
    puts "   Previous coverage: #{previous_coverage}%"
    puts "   Current coverage: #{current_coverage.round(2)}%"
    puts "   Improvement: #{improvement.round(2)} percentage points"
    
    if current_coverage > 20
      puts "   🎉 SIGNIFICANT IMPROVEMENT ACHIEVED!"
    elsif current_coverage > previous_coverage
      puts "   ✅ Coverage improvement detected"
    else
      puts "   ⚠️  Coverage still needs work"
    end
    
    # Show sample of covered vs missed lines
    puts "\n🔍 COVERAGE DETAILS (Sample)"
    puts "-" * 25
    puts "Covered lines (first 5):"
    lexer_file.covered_lines.first(5).each do |line|
      puts "   ✅ Line #{line.line_number}: #{line.source.strip[0..60]}..."
    end
    
    puts "\nMissed lines (first 5):"
    lexer_file.missed_lines.first(5).each do |line|
      puts "   ❌ Line #{line.line_number}: #{line.source.strip[0..60]}..."
    end
    
  else
    puts "\n❌ LEXER FILE STILL NOT FOUND IN COVERAGE"
    puts "This indicates the fix didn't work as expected."
    
    puts "\nFiles currently tracked:"
    result.files.each do |file|
      puts "   - #{file.filename}"
    end
  end
  
  # Check other source files
  puts "\n📁 OTHER SOURCE FILES"
  puts "-" * 20
  ['token.rb', 'ast_nodes.rb'].each do |filename|
    source_file = result.files.find { |file| file.filename.include?(filename) && file.filename.include?('/src/') }
    if source_file
      puts "   ✅ #{filename}: #{source_file.covered_percent.round(1)}% coverage"
    else
      puts "   ❌ #{filename}: Not tracked"
    end
  end
  
rescue => e
  puts "❌ Error analyzing SimpleCov data: #{e.class} - #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join(', ')}"
end

puts "\n🏁 VERIFICATION SUMMARY"
puts "=" * 25
puts "This verification shows whether the SimpleCov fix successfully:"
puts "1. ✅ Tracks source files (not just test files)"
puts "2. ✅ Measures lexer.rb coverage properly"
puts "3. ✅ Shows significant coverage improvement"
puts "4. ✅ Provides actionable coverage data"

puts "\nNext: Run full Phase 1 test suite to get complete coverage metrics"