require 'simplecov'

# Configure SimpleCov to focus on lexer coverage measurement
SimpleCov.start do
  enable_coverage :branch
  
  # Set root to project directory 
  root File.expand_path('../../', __FILE__)
  
  # Add filters - exclude test files from coverage measurement
  add_filter '/test/'
  
  # Focus only on lexer file
  add_filter do |source_file|
    !source_file.filename.end_with?('src/lexer.rb')
  end
  
  # Set coverage directory
  coverage_dir 'test/coverage'
end

# Load only the lexer and dependencies for focused coverage
require_relative '../patlang-core/lexer/lexer'
require_relative '../patlang-core/lexer/token'

require 'minitest/autorun'

# Import the targeted test suite
require_relative 'infrastructure/lexer_80_percent_coverage_test_suite'

# Also run any existing lexer tests for baseline comparison
Dir['test/infrastructure/test_lexer*.rb'].each do |test_file|
  require_relative File.basename(test_file, '.rb')
end

puts "\n🎯 FOCUSED LEXER COVERAGE MEASUREMENT"
puts "================================================"
puts "Running targeted lexer coverage test suite..."
puts "Target: Boost from 70.28% to 80%+ lexer coverage"
puts "================================================\n"

# After tests complete, SimpleCov will automatically generate the coverage report
at_exit do
  puts "\n📊 LEXER COVERAGE ANALYSIS COMPLETE"
  puts "Check test/coverage/index.html for detailed lexer coverage report"
end