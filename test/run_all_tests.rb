require 'simplecov'
require 'pathname'

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
require_relative 'helpers/test_helper'

# Dynamically discover and load all test files from all subdirectories
test_dir = File.dirname(__FILE__)
test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort

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
  relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
  basename = File.basename(file, '.rb')
  puts "  - #{relative_path}"
  require_relative relative_path.sub('.rb', '')
end

puts "\nAll test files loaded successfully!"
