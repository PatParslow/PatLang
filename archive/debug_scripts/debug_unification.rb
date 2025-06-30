require_relative 'src/reasoning/unification_engine'

# Test basic variable unification
engine = UnificationEngine.new
var = TypeVariable.new(:X)
substitution = {}

puts "Testing variable unification with atom..."
result = engine.unify(var, :hello, substitution)
puts "Result: #{result}"
puts "Substitution: #{substitution}"
puts "Variable name: #{var.name}"
puts "Substitution keys: #{substitution.keys}"
puts "Substitution[:X]: #{substitution[:X]}"

# Test with nil terms
puts "\nTesting nil terms..."
begin
  engine.unify(nil, :atom, {})
rescue => e
  puts "Exception caught: #{e.message}"
end

# Test substitution validation
puts "\nTesting substitution validation..."
begin
  engine.unify(:a, :a, "not a hash")
rescue => e
  puts "Exception caught: #{e.message}"
end