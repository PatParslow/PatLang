#!/usr/bin/env ruby

require 'simplecov'
require 'json'

# Configure SimpleCov for detailed analysis
SimpleCov.start do
  add_filter '/test/'
  enable_coverage :branch
  track_files 'src/**/*.rb'
  
  # Focus on core components
  add_group 'Core Lexer', ['src/lexer.rb']
  add_group 'Core Parser', ['src/parser.rb']
  add_group 'Core Evaluator', ['src/evaluator.rb']
  add_group 'Core AST Nodes', ['src/ast_nodes.rb']
  add_group 'Core Token', ['src/token.rb']
  
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
end

puts "🔍 COMPREHENSIVE PATLANG CORE COMPONENT COVERAGE ANALYSIS"
puts "=" * 70

# Load the core components to analyze
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/ast_nodes'
require_relative 'src/token'
require_relative 'ruby-host/bootstrap/patlang'

# Test basic functionality to trigger code execution
puts "\n📊 TRIGGERING CODE EXECUTION FOR COVERAGE ANALYSIS:"

# Test lexer functionality
test_expressions = [
  "42",
  "hello world",
  "2 + 3 * 4",
  "(1 + 2) * 3",
  "x = 5",
  "if true then 1 else 2 end",
  "make function test() { return 42 }",
  "\"hello\"",
  "true",
  "false",
  "nil",
  "x > 5 and y < 10",
  "not false",
  "[1, 2, 3]",
  "{key: value}",
  "function_call(arg1, arg2)"
]

lexer_coverage_data = {}
parser_coverage_data = {}
evaluator_coverage_data = {}

test_expressions.each do |expr|
  puts "  Testing: #{expr}"
  
  begin
    # Test lexer
    lexer = Lexer.new(expr)
    tokens = lexer.tokenize
    lexer_coverage_data[expr] = { success: true, tokens: tokens.length }
    
    # Test parser
    parser = Parser.new(tokens)
    ast = parser.parse
    parser_coverage_data[expr] = { success: true, ast: ast.class.name }
    
    # Test evaluator for simple expressions
    if ['42', '2 + 3', '(1 + 2) * 3', 'true', 'false'].include?(expr)
      result = Patlang.process_expression(expr)
      evaluator_coverage_data[expr] = { success: true, result: result }
    end
    
  rescue => e
    puts "    ❌ Error: #{e.message}"
    lexer_coverage_data[expr] = { success: false, error: e.message }
  end
end

# Test AST node creation directly
puts "\n🌳 TESTING AST NODE CREATION:"
ast_nodes_tested = []

begin
  # Test NumberNode
  num_node = NumberNode.new(42)
  ast_nodes_tested << num_node.class.name
  
  # Test BinaryOpNode
  left = NumberNode.new(2)
  right = NumberNode.new(3)
  bin_node = BinaryOpNode.new(left, '+', right)
  ast_nodes_tested << bin_node.class.name
  
  # Test UnaryOpNode
  unary_node = UnaryOpNode.new('-', NumberNode.new(5))
  ast_nodes_tested << unary_node.class.name
  
  puts "  ✅ AST Nodes tested: #{ast_nodes_tested.join(', ')}"
rescue => e
  puts "  ❌ AST Node testing error: #{e.message}"
end

puts "\n📈 COVERAGE ANALYSIS COMPLETE"
puts "=" * 70

# The coverage report will be generated automatically
puts "\nCoverage report will be available at: coverage/index.html"
puts "Line Coverage: #{SimpleCov.result.covered_percent.round(2)}%"

# Create detailed analysis report
analysis_report = {
  timestamp: Time.now.iso8601,
  overall_coverage: {
    line_coverage: SimpleCov.result.covered_percent.round(2),
    lines_covered: SimpleCov.result.covered_lines,
    total_lines: SimpleCov.result.covered_lines + SimpleCov.result.missed_lines
  },
  core_components: {},
  test_results: {
    lexer: lexer_coverage_data,
    parser: parser_coverage_data,
    evaluator: evaluator_coverage_data,
    ast_nodes: ast_nodes_tested
  }
}

# Analyze each core component
core_files = ['src/lexer.rb', 'src/parser.rb', 'src/evaluator.rb', 'src/ast_nodes.rb', 'src/token.rb']
core_files.each do |file|
  if SimpleCov.result.files.any? { |f| f.filename.end_with?(file) }
    file_result = SimpleCov.result.files.find { |f| f.filename.end_with?(file) }
    analysis_report[:core_components][file] = {
      coverage_percent: file_result.covered_percent.round(2),
      lines_covered: file_result.covered_lines.count,
      total_lines: file_result.lines.count,
      missed_lines: file_result.missed_lines.map(&:line_number),
      never_lines: file_result.never_lines.map(&:line_number)
    }
  end
end

# Save analysis report
File.write('coverage_analysis_report.json', JSON.pretty_generate(analysis_report))
puts "\nDetailed analysis saved to: coverage_analysis_report.json"