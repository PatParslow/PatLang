#!/usr/bin/env ruby

# Lexer Coverage Integration Diagnostic Tool
# Purpose: Identify why lexer coverage shows only 8.4% despite comprehensive tests

require 'simplecov'

# Start coverage tracking
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_group 'Source', 'src'
end

puts "🔍 LEXER COVERAGE INTEGRATION DIAGNOSTIC"
puts "=" * 60

# Step 1: Verify source file paths and loading
puts "\n📁 STEP 1: Source File Analysis"
puts "-" * 30

lexer_path = File.expand_path('../../src/lexer.rb', __FILE__)
puts "Lexer source path: #{lexer_path}"
puts "Lexer file exists: #{File.exist?(lexer_path)}"

if File.exist?(lexer_path)
  puts "Lexer file size: #{File.size(lexer_path)} bytes"
  puts "Lexer file readable: #{File.readable?(lexer_path)}"
end

# Step 2: Test require path resolution
puts "\n📥 STEP 2: Require Path Testing"
puts "-" * 30

begin
  puts "Attempting to require lexer..."
  require_relative '../patlang-core/lexer/lexer'
  puts "✅ Lexer required successfully"
  
  # Check if Lexer class is defined
  if defined?(Lexer)
    puts "✅ Lexer class is defined"
    puts "Lexer class location: #{Lexer.method(:new).source_location}"
  else
    puts "❌ Lexer class not defined after require"
  end
  
rescue LoadError => e
  puts "❌ LoadError requiring lexer: #{e.message}"
rescue => e
  puts "❌ Error requiring lexer: #{e.class} - #{e.message}"
end

# Step 3: Test instantiation and method calls
puts "\n🧪 STEP 3: Lexer Instantiation Test"
puts "-" * 30

begin
  if defined?(Lexer)
    lexer = Lexer.new("test input")
    puts "✅ Lexer instantiated successfully"
    
    # Test a few method calls to ensure code execution
    token = lexer.get_next_token
    puts "✅ get_next_token executed: #{token.class}"
    
    lexer2 = Lexer.new("42 + 3")
    tokens = lexer2.tokenize
    puts "✅ tokenize executed: #{tokens.length} tokens"
    
  else
    puts "❌ Cannot test instantiation - Lexer class not defined"
  end
rescue => e
  puts "❌ Error during lexer testing: #{e.class} - #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join(', ')}"
end

# Step 4: Load and execute actual test file
puts "\n🧪 STEP 4: Test File Execution Analysis"
puts "-" * 30

begin
  puts "Loading test helper..."
  require_relative 'helpers/test_helper'
  puts "✅ Test helper loaded"
  
  puts "Loading lexer test file..."
  require_relative 'core/test_lexer_comprehensive'
  puts "✅ Lexer test file loaded"
  
  # Run a single test method to see if it exercises the lexer
  if defined?(TestLexerComprehensive)
    puts "✅ TestLexerComprehensive class found"
    
    test_instance = TestLexerComprehensive.new(:test_lexer_initialization_basic)
    puts "Test instance created: #{test_instance.class}"
    
    # Run one test method
    test_instance.setup
    test_instance.test_lexer_initialization_basic
    puts "✅ Sample test method executed successfully"
    
  else
    puts "❌ TestLexerComprehensive class not found"
  end
  
rescue => e
  puts "❌ Error during test execution: #{e.class} - #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
end

# Step 5: SimpleCov analysis
puts "\n📊 STEP 5: SimpleCov Coverage Analysis"
puts "-" * 30

begin
  # Force SimpleCov to calculate results
  SimpleCov.result.format!
  
  # Get coverage data
  result = SimpleCov.result
  puts "Total files tracked: #{result.files.count}"
  
  # Find lexer file in coverage data
  lexer_file = result.files.find { |file| file.filename.include?('lexer.rb') }
  
  if lexer_file
    puts "✅ Lexer file found in coverage data"
    puts "   Filename: #{lexer_file.filename}"
    puts "   Lines covered: #{lexer_file.covered_lines.count}"
    puts "   Lines missed: #{lexer_file.missed_lines.count}"
    puts "   Total lines: #{lexer_file.lines.count}"
    puts "   Coverage percentage: #{lexer_file.covered_percent.round(2)}%"
    
    # Show first few missed lines for analysis
    puts "\n🔍 First 10 missed lines:"
    lexer_file.missed_lines.first(10).each do |line|
      puts "   Line #{line.line_number}: #{line.source.strip}"
    end
    
  else
    puts "❌ Lexer file NOT found in coverage data"
    puts "Files being tracked:"
    result.files.each do |file|
      puts "   - #{file.filename}"
    end
  end
  
rescue => e
  puts "❌ Error analyzing SimpleCov data: #{e.class} - #{e.message}"
end

# Step 6: Manual line execution test
puts "\n🎯 STEP 6: Manual Code Path Execution Test"
puts "-" * 30

begin
  if defined?(Lexer)
    puts "Testing specific lexer code paths..."
    
    # Test different input types to exercise various code paths
    test_inputs = [
      "hello",           # identifier
      "123",            # number
      '"string"',       # string
      "42 + 3.14",      # complex expression
      "# comment\ncode", # comment handling
      "invalid§chars",   # error handling
      "",               # empty input
      "if then else",   # keywords
      "make a function" # function keywords
    ]
    
    test_inputs.each_with_index do |input, i|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      puts "   Input #{i+1}: '#{input.gsub("\n", "\\n")}' → #{tokens.length} tokens"
    end
    
    puts "✅ Manual code path testing completed"
    
  else
    puts "❌ Cannot test code paths - Lexer not available"
  end
  
rescue => e
  puts "❌ Error in manual testing: #{e.class} - #{e.message}"
end

puts "\n📋 DIAGNOSTIC SUMMARY"
puts "=" * 30
puts "This diagnostic will help identify:"
puts "1. Whether the lexer source file is being properly loaded"
puts "2. If SimpleCov is tracking the correct file"
puts "3. Whether test execution actually calls lexer methods"
puts "4. What specific code paths are being missed"
puts "\nNext: Run comprehensive test suite and compare results"