#!/usr/bin/env ruby

puts "=== Phase 2 Reasoning System Error Validation ==="

# Test each file individually without test framework dependencies
files_to_check = [
  'src/reasoning/unification_engine.rb',
  'src/reasoning/type_constraint_system.rb', 
  'src/reasoning/type_constraint.rb',
  'src/reasoning/reasoning_coordinator.rb'
]

files_to_check.each do |file|
  puts "\nChecking #{file}..."
  if File.exist?(file)
    begin
      load file
      puts "  ✓ #{file} loads successfully"
    rescue => e
      puts "  ✗ #{file} error: #{e.message}"
      puts "  Error location: #{e.backtrace.first}"
      puts "  Full backtrace:"
      e.backtrace[0..5].each { |line| puts "    #{line}" }
    end
  else
    puts "  ✗ File not found: #{file}"
  end
end

puts "\n=== Validation Complete ==="