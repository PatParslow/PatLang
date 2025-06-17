#!/usr/bin/env ruby

# Enable SimpleCov for this test
require 'simplecov'

# Load configuration
require_relative 'helpers/config_loader'

# Configure SimpleCov using our consolidated config
simplecov_config = TestConfigLoader.simplecov_config
reporting_config = TestConfigLoader.coverage_reporting

SimpleCov.start do
  # Set coverage directory to consolidated location
  coverage_dir reporting_config[:output_directory]
  
  # Apply filters
  simplecov_config[:filters].each do |filter|
    add_filter filter
  end
  
  # Apply groups
  simplecov_config[:groups].each do |name, pattern|
    add_group name, pattern
  end
  
  # Set minimum coverage
  thresholds = TestConfigLoader.coverage_thresholds
  minimum_coverage thresholds[:minimum_line]
  minimum_coverage_by_file thresholds[:minimum_line]
end

puts "🧪 COVERAGE GENERATION TEST"
puts "=" * 60
puts "📊 SimpleCov configured to use: #{reporting_config[:output_directory]}"

# Require some source files to generate coverage
begin
  require_relative '../src/patlang/lexer'
  require_relative '../src/patlang/parser'
  require_relative '../src/patlang/evaluator'
  
  puts "✅ Source files loaded successfully"
  
  # Create some instances to trigger coverage
  lexer = Patlang::Lexer.new("test input")
  tokens = lexer.tokenize
  
  parser = Patlang::Parser.new(tokens)
  ast = parser.parse
  
  evaluator = Patlang::Evaluator.new
  result = evaluator.evaluate(ast)
  
  puts "✅ Code execution completed - coverage should be generated"
  
rescue LoadError => e
  puts "⚠️  Could not load all source files: #{e.message}"
  puts "   This is expected if some files don't exist yet"
rescue => e
  puts "⚠️  Code execution error: #{e.message}"
  puts "   This is expected - we're just generating coverage"
end

# Force SimpleCov to write results
SimpleCov.result.format!

puts "📊 Coverage generation completed"
puts "📁 Check coverage files in: #{reporting_config[:output_directory]}"