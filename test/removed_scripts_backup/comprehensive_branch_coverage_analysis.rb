#!/usr/bin/env ruby

require 'simplecov'
require 'json'
require 'fileutils'

# Configure SimpleCov for comprehensive branch coverage analysis
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_filter '/tools/'
  add_filter '/docs/'
  track_files 'src/**/*.rb'
  
  # Detailed coverage reporting with multiple formats
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  # Focus on reasoning components
  add_group 'Reasoning Core', 'src/reasoning'
  add_group 'Evaluator', 'src/evaluator'
  add_group 'Parser', 'src/parser'
  add_group 'Object Model', 'src/object_model'
  add_group 'Main Components', ['src/lexer.rb', 'src/parser.rb', 'src/evaluator.rb']
  
  # Set coverage requirements
  minimum_coverage line: 95, branch: 90
end

puts "🔍 PATLANG Unified Reasoning System - Comprehensive Branch Coverage Analysis"
puts "=" * 80

# Helper method to safely require files
def safe_require(file_path)
  begin
    require_relative file_path
    true
  rescue LoadError, SyntaxError => e
    puts "⚠️  Warning: Could not load #{file_path}: #{e.message}"
    false
  end
end

# Load test helper
safe_require 'helpers/test_helper'

# Collect all test files
test_files = []

# Infrastructure tests (core reasoning components)
infrastructure_tests = Dir.glob('infrastructure/test_*.rb')
test_files.concat(infrastructure_tests)

# Integration tests
integration_tests = Dir.glob('integration/test_*.rb')
test_files.concat(integration_tests)

# Language-specific tests
language_tests = Dir.glob('patlang_language/test_*.rb')
test_files.concat(language_tests)

# Ruby implementation tests
ruby_tests = Dir.glob('ruby_implementation/test_*.rb')
test_files.concat(ruby_tests)

puts "\n📊 Test Suite Overview:"
puts "Infrastructure tests: #{infrastructure_tests.length}"
puts "Integration tests: #{integration_tests.length}"
puts "Language tests: #{language_tests.length}"
puts "Ruby implementation tests: #{ruby_tests.length}"
puts "Total test files: #{test_files.length}"

# Load all test files
loaded_count = 0
test_files.each do |test_file|
  if safe_require test_file
    loaded_count += 1
  end
end

puts "\n✅ Successfully loaded #{loaded_count}/#{test_files.length} test files"

# Analysis of reasoning components before running tests
reasoning_files = Dir.glob('../src/reasoning/*.rb')
puts "\n🧠 Reasoning Components to Analyze:"
reasoning_files.each do |file|
  puts "  - #{File.basename(file)}"
end

puts "\n🚀 Running comprehensive test suite with branch coverage..."
puts "This may take several minutes..."

# Load minitest and run tests
require 'minitest/autorun'

# Create a custom analysis after tests complete
at_exit do
  puts "\n" + "=" * 80
  puts "📈 COVERAGE ANALYSIS COMPLETE"
  puts "=" * 80
  
  # Access SimpleCov result
  result = SimpleCov.result
  
  if result
    puts "\n📊 Overall Coverage Statistics:"
    puts "Line Coverage: #{result.covered_percent.round(2)}%"
    
    # Branch coverage statistics if available
    if result.respond_to?(:branch_coverage_percent)
      puts "Branch Coverage: #{result.branch_coverage_percent.round(2)}%"
    end
    
    puts "\n🎯 Reasoning Components Analysis:"
    
    reasoning_files.each do |file_path|
      relative_path = file_path.gsub('../', '')
      file_result = result.files.find { |f| f.filename.end_with?(relative_path) }
      
      if file_result
        puts "\n#{File.basename(file_path)}:"
        puts "  Line Coverage: #{file_result.covered_percent.round(2)}%"
        puts "  Lines: #{file_result.covered_lines.count}/#{file_result.lines.count}"
        
        # Identify uncovered lines
        uncovered_lines = file_result.lines.each_with_index.select { |line, idx| line && line.coverage == 0 }.map { |line, idx| idx + 1 }
        if uncovered_lines.any?
          puts "  ⚠️  Uncovered lines: #{uncovered_lines.join(', ')}"
        end
        
        # Branch coverage if available
        if file_result.respond_to?(:branches) && file_result.branches.any?
          total_branches = file_result.branches.count
          covered_branches = file_result.branches.count { |branch| branch.coverage > 0 }
          branch_percent = total_branches > 0 ? (covered_branches.to_f / total_branches * 100).round(2) : 0
          puts "  Branch Coverage: #{branch_percent}% (#{covered_branches}/#{total_branches})"
          
          # Identify uncovered branches
          uncovered_branches = file_result.branches.select { |branch| branch.coverage == 0 }
          if uncovered_branches.any?
            puts "  ⚠️  Uncovered branches found: #{uncovered_branches.length}"
          end
        end
      else
        puts "\n#{File.basename(file_path)}: ❌ No coverage data found"
      end
    end
    
    # Generate detailed coverage gaps report
    gaps_file = 'test/coverage/branch_coverage_gaps.json'
    FileUtils.mkdir_p('test/coverage')
    
    gaps_data = {
      timestamp: Time.now.iso8601,
      overall_line_coverage: result.covered_percent,
      overall_branch_coverage: result.respond_to?(:branch_coverage_percent) ? result.branch_coverage_percent : 'N/A',
      reasoning_components: {},
      recommendations: []
    }
    
    reasoning_files.each do |file_path|
      file_result = result.files.find { |f| f.filename.end_with?(file_path) }
      component_name = File.basename(file_path, '.rb')
      
      if file_result
        uncovered_lines = file_result.lines.each_with_index.select { |line, idx| line && line.coverage == 0 }.map { |line, idx| idx + 1 }
        
        gaps_data[:reasoning_components][component_name] = {
          line_coverage: file_result.covered_percent,
          uncovered_lines: uncovered_lines,
          total_lines: file_result.lines.count,
          covered_lines: file_result.covered_lines.count
        }
        
        # Add recommendations for low coverage components
        if file_result.covered_percent < 90
          gaps_data[:recommendations] << "#{component_name}: Line coverage below 90% - needs additional tests"
        end
        
        if uncovered_lines.length > 5
          gaps_data[:recommendations] << "#{component_name}: #{uncovered_lines.length} uncovered lines - focus on error handling and edge cases"
        end
      end
    end
    
    File.write(gaps_file, JSON.pretty_generate(gaps_data))
    puts "\n💾 Detailed gaps analysis saved to: #{gaps_file}"
    
    puts "\n📋 Coverage Reports Generated:"
    puts "  - HTML Report: coverage/index.html"
    puts "  - JSON Report: coverage/.resultset.json"
    puts "  - Gap Analysis: #{gaps_file}"
    
    puts "\n🎯 Next Steps:"
    if gaps_data[:recommendations].any?
      puts "  Priority improvements needed:"
      gaps_data[:recommendations].each { |rec| puts "    • #{rec}" }
    else
      puts "  ✅ Coverage targets met for reasoning components!"
    end
  else
    puts "❌ No coverage data available"
  end
end