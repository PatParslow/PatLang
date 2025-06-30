#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'
require_relative 'src/patlang'

puts "🔍 COMPREHENSIVE PARSER REGRESSION ASSESSMENT"
puts "=" * 60

# Test 1: Check for missing AST nodes
puts "\n1. AST NODE AVAILABILITY CHECK"
puts "-" * 40

missing_nodes = []
required_nodes = [
  'UnaryOpNode',    # For unary minus operations
  'PrintNode'       # For print statements
]

required_nodes.each do |node_name|
  begin
    Object.const_get(node_name)
    puts "✅ #{node_name} exists"
  rescue NameError
    puts "❌ #{node_name} MISSING"
    missing_nodes << node_name
  end
end

existing_nodes = [
  'IndexAccessNode',  # For string[index] operations
  'FunctionDefinitionNode',
  'FunctionCallNode',
  'ParameterNode',
  'ReturnNode'
]

existing_nodes.each do |node_name|
  begin
    Object.const_get(node_name)
    puts "✅ #{node_name} exists"
  rescue NameError
    puts "❌ #{node_name} MISSING"
    missing_nodes << node_name
  end
end

# Test 2: Test critical parsing scenarios mentioned in the task
puts "\n2. CRITICAL PARSING SCENARIOS TEST"
puts "-" * 40

test_cases = [
  {
    name: "Unary minus parsing",
    code: "-5",
    expected_type: "should parse as UnaryOpNode or similar"
  },
  {
    name: "String indexing",
    code: '"hello"[0]',
    expected_type: "should parse as IndexAccessNode"
  },
  {
    name: "Basic arithmetic",
    code: "5 + 3",
    expected_type: "should parse as BinaryOpNode"
  },
  {
    name: "Variable assignment",
    code: "x = 5",
    expected_type: "should parse as AssignmentNode"
  },
  {
    name: "Function definition",
    code: 'make a function called test { return "hello" }',
    expected_type: "should parse as FunctionDefinitionNode"
  },
  {
    name: "Function call",
    code: "call test",
    expected_type: "should parse as FunctionCallNode"
  }
]

test_cases.each do |test|
  puts "\nTesting: #{test[:name]}"
  puts "Code: #{test[:code]}"
  puts "Expected: #{test[:expected_type]}"
  
  begin
    lexer = Lexer.new(test[:code])
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "✅ Parsed successfully as: #{ast.class}"
  rescue => e
    puts "❌ Parse error: #{e.message}"
  end
end

# Test 3: Test evaluation of critical scenarios
puts "\n3. EVALUATION TEST"
puts "-" * 40

eval_tests = [
  {
    name: "Simple arithmetic",
    code: "5 + 3",
    expected: "8"
  },
  {
    name: "String literal",
    code: '"hello"',
    expected: '"hello"'
  },
  {
    name: "Unary minus (if supported)",
    code: "-5",
    expected: "-5 or error if not implemented"
  },
  {
    name: "String indexing (if supported)", 
    code: '"hello"[0]',
    expected: '"h" or error if not implemented'
  }
]

eval_tests.each do |test|
  puts "\nEvaluating: #{test[:name]}"
  puts "Code: #{test[:code]}"
  puts "Expected: #{test[:expected]}"
  
  begin
    result = Patlang.evaluate(test[:code])
    puts "✅ Result: #{result.inspect}"
  rescue => e
    puts "❌ Evaluation error: #{e.message}"
  end
end

# Test 4: Check current parser capabilities vs todo_response.md requirements
puts "\n4. TODO_RESPONSE.MD REQUIREMENTS CHECK"
puts "-" * 40

puts "Checking if current parser matches documented requirements..."

# Check if current parser has the features documented in todo_response.md
features_to_check = [
  "Ambiguous token resolution",
  "String indexing support", 
  "Unary operator support",
  "Assignment parsing",
  "Function definition parsing",
  "Function call parsing"
]

features_to_check.each do |feature|
  puts "📋 #{feature}: Needs manual verification against todo_response.md"
end

# Summary
puts "\n5. SUMMARY OF FINDINGS"
puts "-" * 40

if missing_nodes.empty?
  puts "✅ All required AST nodes are present"
else
  puts "❌ Missing AST nodes: #{missing_nodes.join(', ')}"
end

puts "\n📊 Assessment complete. Key findings:"
puts "- Current AST nodes available in codebase"
puts "- Basic parsing and evaluation capabilities tested"
puts "- Specific missing features identified"
puts "- Ready for detailed gap analysis against todo_response.md requirements"