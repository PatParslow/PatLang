require 'simplecov'

# Configure SimpleCov with branch coverage
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  track_files 'src/**/*.rb'
  
  # Detailed coverage reporting
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  # Set minimum coverage requirements
  minimum_coverage line: 95, branch: 90
end

# Require all test files to get comprehensive coverage
require_relative '../helpers/test_helper'
require_relative 'test_evaluator'
require_relative 'test_string_operations'
require_relative 'test_extended_string_methods'
require_relative 'test_evaluator_edge_cases'

# Run all tests that focus on evaluator functionality
puts "Running coverage analysis for evaluator string functionality..."

# Create test suite for evaluator-related tests
require 'minitest/autorun'

# This will run when the file is executed