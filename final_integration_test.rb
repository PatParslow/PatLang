#!/usr/bin/env ruby

# Final integration test to demonstrate the fix working in practice

require_relative 'src/reasoning/reasoning_coordinator'

puts "=" * 60
puts "FINAL REASONING COORDINATION INTEGRATION TEST"
puts "=" * 60
puts

begin
  # Create a reasoning coordinator (like the original failing scenario)
  evaluator = Object.new
  coordinator = ReasoningCoordinator.new(evaluator)
  coordinator.enable_reasoning_mode
  
  # Add some test data to generate statistics
  coordinator.create_constraint("x", :type, :number)
  coordinator.create_constraint("y", :range, {min: 1, max: 100})
  
  # This was the line that was failing before our fix
  puts "Calling coordinator.statistics (this was failing before)..."
  stats = coordinator.statistics
  
  puts "✅ SUCCESS! coordinator.statistics completed without errors"
  puts
  puts "Statistics data returned:"
  stats.each do |key, value|
    puts "  #{key}: #{value}"
  end
  puts
  
  # Test that unification statistics are properly included
  if stats[:unification_stats]
    puts "✅ Unification statistics properly included:"
    stats[:unification_stats].each do |key, value|
      puts "    #{key}: #{value}"
    end
  else
    puts "❌ ERROR: Unification statistics missing"
    exit 1
  end
  
  puts
  puts "🎉 INTEGRATION FIX SUCCESSFUL!"
  puts "✅ Missing UnificationEngine.statistics method has been implemented"
  puts "✅ Missing TypeConstraintSystem.constraint_count method has been implemented"
  puts "✅ ReasoningCoordinator can now gather performance metrics from all components"
  puts "✅ Integration between UnificationEngine and reasoning coordinator working"
  
rescue => e
  puts "❌ INTEGRATION TEST FAILED!"
  puts "Error: #{e.message}"
  puts e.backtrace.first(3)
  exit 1
end