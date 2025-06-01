require 'simplecov'

# Configure SimpleCov with branch coverage for comprehensive analysis
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  track_files 'src/**/*.rb'
  
  # Detailed coverage reporting
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  # Set coverage requirements
  minimum_coverage line: 95, branch: 90
end

puts "Running comprehensive test suite with coverage analysis..."

# Always load test_helper first
require_relative 'test_helper'

# Dynamically discover and load all test files
test_dir = File.dirname(__FILE__)
test_files = Dir.glob(File.join(test_dir, 'test_*.rb')).sort

# Filter out helper files and non-test files
excluded_files = [
  'test_helper.rb',
  'run_all_tests.rb'
]

test_files_to_load = test_files.select do |file|
  basename = File.basename(file)
  !excluded_files.include?(basename) && basename.start_with?('test_')
end

puts "Discovered #{test_files_to_load.length} test files:"
test_files_to_load.each do |file|
  basename = File.basename(file, '.rb')
  puts "  - #{basename}"
  require_relative basename
end

puts "\nAll test files loaded successfully!"