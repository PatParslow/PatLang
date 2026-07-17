require 'tempfile'
require_relative 'evaluator_old'
require_relative '../../patlang-core/ast/ast_nodes'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/parser/parser'

# Write a temp file with a simple assignment
Tempfile.create(['included', '.patlang']) do |f|
  f.write("x = 123")
  f.flush

  # Build an IncludeNode pointing to the temp file
  expr_node = StringNode.new(f.path)
  include_node = IncludeNode.new(expr_node)

  evaluator = Evaluator.new
  evaluator.evaluate(include_node)
  result = evaluator.instance_variable_get(:@variables)['x']

  if result == 123
    puts "IncludeNode test passed: x == 123"
  else
    puts "IncludeNode test failed: x == #{result.inspect}"
  end
end
# Test IncludeNode with an expression that evaluates to a string
Tempfile.create(['included_expr', '.patlang']) do |f|
  f.write("y = 456")
  f.flush

  # Simulate an expression node that returns the filename string
  expr_node = Object.new
  def expr_node.evaluate(_ctx = nil); @filename; end
  expr_node.instance_variable_set(:@filename, f.path)
  def expr_node.is_a?(klass); klass == StringNode || super; end

  include_node = IncludeNode.new(expr_node)
  evaluator = Evaluator.new
  def evaluator.evaluate(node)
    node.respond_to?(:evaluate) ? node.evaluate(self) : super(node)
  end
  evaluator.evaluate(include_node)
  result = evaluator.instance_variable_get(:@variables)['y']

  if result == 456
    puts "IncludeNode expression test passed: y == 456"
  else
    puts "IncludeNode expression test failed: y == #{result.inspect}"
    exit 1
  end
end

# Test IncludeNode with a non-string value
begin
  expr_node = Object.new
  def expr_node.evaluate(_ctx = nil); 42; end
  include_node = IncludeNode.new(expr_node)
  evaluator = Evaluator.new
  def evaluator.evaluate(node)
    node.respond_to?(:evaluate) ? node.evaluate(self) : super(node)
  end
  evaluator.evaluate(include_node)
  puts "IncludeNode non-string test failed: no error raised"
  exit 1
rescue => e
  if e.message =~ /filename must be a String, got 42 \(Integer\)/
    puts "IncludeNode non-string test passed: #{e.message}"
  else
    puts "IncludeNode non-string test failed: #{e.message}"
    exit 1
  end
end