#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplecov'

# Configure SimpleCov
SimpleCov.configure do
  command_name 'Lexer Phase 3 Tests'
  add_filter '/test/'
  enable_coverage :branch
  coverage_dir 'test/coverage/lexer_phase3'
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
end

SimpleCov.start

puts "🧪 SIMPLE LEXER PHASE 3 COVERAGE TEST"
puts "=" * 45

# Load lexer classes
require_relative 'src/lexer'
require_relative 'src/token'

puts "✅ Lexer classes loaded"

# Run just the Phase 3 tests with coverage
puts "\n🎯 Running Phase 3 lexer tests..."

# Change to test directory and run the specific test
result = system("cd test && ruby infrastructure/test_lexer_edge_cases_final.rb")

puts "\n📊 Test execution completed with result: #{result}"

# Generate coverage report
coverage_result = SimpleCov.result
puts "\n📈 COVERAGE RESULTS:"

lexer_file = coverage_result.source_files.find { |f| f.filename.end_with?('src/lexer.rb') }

if lexer_file
  puts "   📄 File: src/lexer.rb"
  puts "   📏 Total Lines: #{lexer_file.lines.count}"
  puts "   ✅ Covered Lines: #{lexer_file.covered_lines.count}"
  puts "   ❌ Missed Lines: #{lexer_file.missed_lines.count}"
  puts "   📈 Line Coverage: #{lexer_file.covered_percent.round(2)}%"
  
  if lexer_file.branches && lexer_file.branches.any?
    total_branches = lexer_file.branches.count
    covered_branches = lexer_file.branches.count { |branch, hits| hits && hits > 0 }
    branch_coverage = total_branches > 0 ? (covered_branches.to_f / total_branches * 100).round(2) : 0
    
    puts "   🌳 Total Branches: #{total_branches}"
    puts "   ✅ Covered Branches: #{covered_branches}"
    puts "   📈 Branch Coverage: #{branch_coverage}%"
  end
  
  puts "\n❌ FIRST 20 MISSED LINES:"
  lexer_file.missed_lines.first(20).each_with_index do |line_num, idx|
    puts "   #{idx + 1}. Line #{line_num}"
  end
  
  puts "\n🔍 COMPARISON:"
  puts "   Previous (HTML report): 44.76% line, 34.78% branch"
  puts "   Current (Phase 3 tests): #{lexer_file.covered_percent.round(2)}% line"
  
  improvement = lexer_file.covered_percent - 44.76
  puts "   📈 Change: #{improvement >= 0 ? '+' : ''}#{improvement.round(2)}%"
  
  if lexer_file.covered_percent > 80
    puts "   🎉 SUCCESS: High coverage achieved!"
  elsif lexer_file.covered_percent > 44.76
    puts "   ✅ IMPROVEMENT: Tests are contributing to coverage"
  else
    puts "   ⚠️  ISSUE: Tests not improving coverage significantly"
  end
  
else
  puts "   ❌ No lexer coverage data found"
end

puts "\n📊 Report: test/coverage/lexer_phase3/index.html"