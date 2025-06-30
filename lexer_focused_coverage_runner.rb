#!/usr/bin/env ruby
# frozen_string_literal: true

# Focused Lexer Coverage Runner
# Runs all lexer tests with SimpleCov to generate accurate coverage data

require 'simplecov'

# Configure SimpleCov specifically for lexer analysis
SimpleCov.configure do
  command_name 'Lexer Tests'
  
  add_filter '/test/'
  add_filter '/bin/'
  add_filter '/tools/'
  add_filter '/docs/'
  add_filter '/examples/'
  add_filter '/archive/'
  
  # Focus specifically on lexer
  add_group "Lexer", "src/lexer.rb"
  
  enable_coverage :branch
  coverage_dir 'test/coverage/lexer_focused'
  
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
end

SimpleCov.start

puts "🎯 FOCUSED LEXER COVERAGE ANALYSIS"
puts "=" * 50

# Ensure lexer is loaded for coverage tracking
require_relative 'src/lexer'
require_relative 'src/token'

puts "\n1️⃣ SimpleCov configured for lexer-focused analysis"
puts "   📊 Coverage tracking: ENABLED"
puts "   🌳 Branch coverage: ENABLED"
puts "   📄 Target: src/lexer.rb"

# Find all lexer test files
lexer_test_files = [
  'test/infrastructure/test_lexer_edge_cases_final.rb',       # Phase 3 - 32 tests, 20,781 assertions
  'test/infrastructure/test_lexer_comprehensive.rb',          # Comprehensive tests
  'test/infrastructure/test_lexer_coverage_enhancement.rb',   # Coverage enhancement
  'test/infrastructure/test_lexer_error_recovery.rb',         # Error recovery
  'test/infrastructure/test_lexer_error_scenarios.rb',        # Error scenarios
  'test/infrastructure/test_lexer_complete_coverage.rb',      # Complete coverage
  'test/infrastructure/test_lexer_branch_coverage.rb',        # Branch coverage
  'test/infrastructure/test_lexer.rb'                         # Basic lexer tests
].select { |file| File.exist?(file) }

puts "\n2️⃣ Found #{lexer_test_files.length} lexer test files:"
lexer_test_files.each { |file| puts "   📄 #{file}" }

# Load minitest framework
require 'minitest/autorun'

puts "\n3️⃣ Loading and executing lexer tests..."

# Disable autorun to prevent automatic execution
Minitest.autorun = false

total_tests = 0
total_assertions = 0
total_failures = 0
total_errors = 0

# Load each test file
lexer_test_files.each do |test_file|
  puts "\n   📦 Loading #{File.basename(test_file)}..."
  
  begin
    # Load the test file
    require_relative test_file
    
    puts "   ✅ Loaded successfully"
  rescue => e
    puts "   ❌ Error loading: #{e.message}"
  end
end

puts "\n4️⃣ Running all loaded lexer tests..."

# Run the tests
options = []
options << '--verbose' if ARGV.include?('--verbose')

# Create a new test runner
runner = Minitest::CompositeReporter.new
runner << Minitest::SummaryReporter.new($stdout, options)
runner << Minitest::ProgressReporter.new($stdout, options)

# Run all tests
results = Minitest.run_via_runner(runner, options)

puts "\n5️⃣ COVERAGE RESULTS ANALYSIS"
puts "=" * 35

# Generate and analyze coverage
coverage_result = SimpleCov.result

puts "\n📊 OVERALL COVERAGE SUMMARY:"
puts "   📈 Total Coverage: #{coverage_result.covered_percent.round(2)}%"
puts "   📄 Files Analyzed: #{coverage_result.source_files.length}"

# Find lexer-specific coverage
lexer_file = coverage_result.source_files.find { |f| f.filename.end_with?('src/lexer.rb') }

if lexer_file
  puts "\n🎯 LEXER-SPECIFIC COVERAGE:"
  puts "   📄 File: #{File.basename(lexer_file.filename)}"
  puts "   📏 Total Lines: #{lexer_file.lines.count}"
  puts "   ✅ Covered Lines: #{lexer_file.covered_lines.count}"
  puts "   ❌ Missed Lines: #{lexer_file.missed_lines.count}"
  puts "   📈 Line Coverage: #{lexer_file.covered_percent.round(2)}%"
  
  # Branch coverage analysis
  if lexer_file.branches && lexer_file.branches.any?
    covered_branches = lexer_file.branches.values.count { |hits| hits > 0 }
    total_branches = lexer_file.branches.count
    branch_coverage = total_branches > 0 ? (covered_branches.to_f / total_branches * 100).round(2) : 0
    
    puts "   🌳 Total Branches: #{total_branches}"
    puts "   ✅ Covered Branches: #{covered_branches}"
    puts "   ❌ Missed Branches: #{total_branches - covered_branches}"
    puts "   📈 Branch Coverage: #{branch_coverage}%"
  end
  
  puts "\n❌ UNCOVERED LINES (first 15):"
  if lexer_file.missed_lines.any?
    lexer_file.missed_lines.first(15).each_with_index do |line_num, idx|
      puts "   #{idx + 1}. Line #{line_num}"
    end
    if lexer_file.missed_lines.length > 15
      puts "   ... and #{lexer_file.missed_lines.length - 15} more"
    end
  else
    puts "   🎉 All lines covered!"
  end
  
else
  puts "\n❌ ERROR: Could not find lexer.rb in coverage data"
  puts "   Available files:"
  coverage_result.source_files.each do |f|
    puts "   📄 #{f.filename}"
  end
end

puts "\n6️⃣ COMPARISON WITH PREVIOUS COVERAGE"
puts "=" * 40

puts "\n📊 PREVIOUS COVERAGE (from HTML report):"
puts "   📈 Line Coverage: 44.76%"
puts "   🌳 Branch Coverage: 34.78%"
puts "   📏 Total Lines: 286 relevant"
puts "   ✅ Covered Lines: 128"
puts "   ❌ Missed Lines: 158"

if lexer_file
  puts "\n📊 NEW COVERAGE (after focused test run):"
  puts "   📈 Line Coverage: #{lexer_file.covered_percent.round(2)}%"
  
  if lexer_file.branches && lexer_file.branches.any?
    covered_branches = lexer_file.branches.values.count { |hits| hits > 0 }
    total_branches = lexer_file.branches.count
    branch_coverage = (covered_branches.to_f / total_branches * 100).round(2)
    puts "   🌳 Branch Coverage: #{branch_coverage}%"
  end
  
  puts "   📏 Total Lines: #{lexer_file.lines.count}"
  puts "   ✅ Covered Lines: #{lexer_file.covered_lines.count}"
  puts "   ❌ Missed Lines: #{lexer_file.missed_lines.count}"
  
  # Calculate improvement
  line_improvement = lexer_file.covered_percent - 44.76
  puts "\n📈 IMPROVEMENT:"
  puts "   🚀 Line Coverage: #{line_improvement >= 0 ? '+' : ''}#{line_improvement.round(2)}%"
  
  if line_improvement > 20
    puts "   🎉 SIGNIFICANT IMPROVEMENT! Tests are working!"
  elsif line_improvement > 0
    puts "   ✅ Some improvement detected"
  else
    puts "   ⚠️  No improvement - investigation needed"
  end
end

puts "\n7️⃣ INVESTIGATION CONCLUSIONS"
puts "=" * 35

if lexer_file && lexer_file.covered_percent > 90
  puts "\n🎉 ISSUE RESOLVED:"
  puts "   ✅ High coverage achieved with focused test run"
  puts "   🔍 Previous report was likely outdated or incomplete"
  puts "   📝 Recommendation: Use this focused coverage approach"
  
elsif lexer_file && lexer_file.covered_percent > 44.76
  puts "\n✅ PARTIAL SUCCESS:"
  puts "   📈 Coverage improved but not at expected level"
  puts "   🔍 Some tests may not be included in main coverage runs"
  puts "   📝 Recommendation: Integrate focused tests into main suite"
  
else
  puts "\n🚨 ISSUE PERSISTS:"
  puts "   ❌ Coverage still low despite comprehensive tests"
  puts "   🔍 Possible causes:"
  puts "     - Tests not exercising all lexer code paths"
  puts "     - Coverage measurement configuration issues"
  puts "     - Dead or unreachable code in lexer"
  puts "   📝 Recommendation: Detailed line-by-line analysis needed"
end

puts "\n📊 Detailed HTML report: test/coverage/lexer_focused/index.html"
puts "🔍 Analysis complete!"