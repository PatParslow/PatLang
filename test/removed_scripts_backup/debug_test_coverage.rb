#!/usr/bin/env ruby

require 'minitest/autorun'
require 'simplecov'

SimpleCov.start do
  add_filter '/test/'
  command_name 'Debug Test Coverage'
end

# Load source files first
require_relative '../src/ast_nodes'
require_relative '../src/lexer'
require_relative '../src/token'

# Load test files
require_relative 'helpers/test_helper'
require_relative 'core/test_ast_nodes_comprehensive'
require_relative 'core/test_lexer_comprehensive'

puts "🔍 Files tracked by SimpleCov during test run:"
puts "=" * 50

# Run a simple test to trigger coverage
result = Minitest.run([])

# Check what files are being tracked
SimpleCov.result.files.each do |file|
  filename = File.basename(file.filename)
  if filename.include?('ast_nodes') || filename.include?('lexer') || filename.include?('token')
    puts "✅ Found: #{filename} - #{file.covered_percent.round(1)}%"
  end
end

puts "\n📊 All source files in coverage:"
SimpleCov.result.files.select { |f| f.filename.include?('src/') }.each do |file|
  puts "  - #{File.basename(file.filename)}: #{file.covered_percent.round(1)}%"
end

puts "\n🎯 Total coverage: #{SimpleCov.result.covered_percent.round(1)}%"