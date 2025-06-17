#!/usr/bin/env ruby

require 'simplecov'

SimpleCov.start do
  add_filter '/test/'
  command_name 'Debug Coverage Check'
end

puts "🔍 Debug: Loading source files for coverage tracking..."

# Load the source files
require_relative 'src/ast_nodes'
require_relative 'src/lexer' 
require_relative 'src/token'

puts "✅ Source files loaded"

# Create some AST nodes to trigger coverage
puts "🧪 Creating test AST nodes..."
number = NumberNode.new(42)
string = StringNode.new("hello")
binary = BinaryOpNode.new(number, :+, NumberNode.new(1))

puts "📊 Checking coverage..."
SimpleCov.result.format!

puts "\n📈 COVERAGE RESULTS:"
puts "=" * 50

SimpleCov.result.files.each do |file|
  if file.filename.include?('src/')
    puts "✅ #{File.basename(file.filename)}: #{file.covered_percent.round(1)}%"
  end
end

total_coverage = SimpleCov.result.covered_percent
puts "\n🎯 Total Coverage: #{total_coverage.round(1)}%"