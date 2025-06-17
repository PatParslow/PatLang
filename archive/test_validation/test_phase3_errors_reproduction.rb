#!/usr/bin/env ruby

puts "=== Phase 3 Error Reproduction Test ==="
puts "Targeting: Evaluator integration + Number object edge cases"
puts

# Test 1: Missing reasoning keywords ("where", "knows", "ancestor")
puts "TEST 1: Missing reasoning keywords in evaluator"
puts "=" * 40

begin
  require_relative 'src/evaluator'
  
  evaluator = Evaluator.new
  evaluator.enable_reasoning_mode
  
  # Test missing "where" keyword
  puts "Testing 'where' keyword..."
  if evaluator.respond_to?(:where)
    puts "✅ 'where' keyword found"
  else
    puts "❌ 'where' keyword MISSING - Phase 3 error"
  end
  
  # Test missing "knows" keyword  
  puts "Testing 'knows' keyword..."
  if evaluator.respond_to?(:knows)
    puts "✅ 'knows' keyword found"
  else
    puts "❌ 'knows' keyword MISSING - Phase 3 error"
  end
  
  # Test missing "ancestor" keyword
  puts "Testing 'ancestor' keyword..."
  if evaluator.respond_to?(:ancestor)
    puts "✅ 'ancestor' keyword found"
  else
    puts "❌ 'ancestor' keyword MISSING - Phase 3 error"
  end
  
rescue => e
  puts "❌ Evaluator integration error: #{e.message}"
  puts "   #{e.backtrace.first}"
end

puts

# Test 2: Number object NaN/Infinity handling
puts "TEST 2: Number object NaN/Infinity edge cases"
puts "=" * 40

begin
  require_relative 'src/object_model/number_object'
  
  # Test NaN handling at line 343
  puts "Testing NaN handling..."
  nan_obj = NumberObject.new(Float::NAN)
  nan_str = nan_obj.to_s
  puts "NaN.to_s = '#{nan_str}'"
  
  # Test Infinity handling
  puts "Testing Infinity handling..."
  inf_obj = NumberObject.new(Float::INFINITY)
  inf_str = inf_obj.to_s
  puts "Infinity.to_s = '#{inf_str}'"
  
  # Test negative Infinity
  puts "Testing -Infinity handling..."
  neg_inf_obj = NumberObject.new(-Float::INFINITY)
  neg_inf_str = neg_inf_obj.to_s
  puts "-Infinity.to_s = '#{neg_inf_str}'"
  
  puts "✅ Basic number object creation works"
  
rescue => e
  puts "❌ Number object error: #{e.message}"
  puts "   #{e.backtrace.first}"
  puts "   This is likely the line 343 NaN/Infinity issue"
end

puts

# Test 3: Variable resolution in scope manager
puts "TEST 3: Variable resolution failures"
puts "=" * 40

begin
  require_relative 'src/evaluator/scope_manager'
  
  scope_mgr = EvaluatorModules::ScopeManager.new
  
  # Test normal variable resolution
  scope_mgr.set_variable("test_var", "test_value")
  result = scope_mgr.get_variable("test_var")
  
  if result == "test_value"
    puts "✅ Basic variable resolution works"
  else
    puts "❌ Variable resolution failed - Phase 3 error"
  end
  
  # Test scope stack operations
  scope_mgr.push_scope
  scope_mgr.set_variable("inner_var", "inner_value")
  
  inner_result = scope_mgr.get_variable("inner_var")
  outer_result = scope_mgr.get_variable("test_var")
  
  if inner_result == "inner_value" && outer_result == "test_value"
    puts "✅ Scope stack resolution works"
  else
    puts "❌ Scope stack resolution failed - Phase 3 error"
  end
  
rescue => e
  puts "❌ Scope manager error: #{e.message}"
  puts "   #{e.backtrace.first}"
end

puts
puts "=== Phase 3 Error Reproduction Complete ==="
puts "Now identifying specific fixes needed..."