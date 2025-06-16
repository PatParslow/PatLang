#!/usr/bin/env ruby

# Simple validation script for division by zero error handling
# Tests the specific division operation without full test framework complexity

puts "=" * 60
puts "TESTING DIVISION BY ZERO ERROR HANDLING FIX"
puts "=" * 60

# Load the Patlang system with error handling
begin
  require_relative 'test/helpers/test_helper'
  
  # Find and require the evaluator
  evaluator_files = Dir.glob('src/**/*evaluator*.rb')
  puts "Found evaluator files: #{evaluator_files}"
  
  if evaluator_files.empty?
    puts "❌ No evaluator files found - searching all Ruby files"
    all_rb_files = Dir.glob('src/**/*.rb')
    puts "All source files:"
    all_rb_files.each { |f| puts "  - #{f}" }
  end
  
  # Try to load main components
  main_files = %w[
    src/main.rb
    src/evaluator.rb
    src/function_evaluator.rb
    src/parser.rb
    src/lexer.rb
  ]
  
  loaded_files = []
  main_files.each do |file|
    if File.exist?(file)
      puts "Loading: #{file}"
      require_relative file
      loaded_files << file
    end
  end
  
  puts "Successfully loaded: #{loaded_files}"
  
rescue => e
  puts "❌ Error loading Patlang system: #{e.class} - #{e.message}"
  puts "Backtrace:"
  e.backtrace[0..5].each { |line| puts "  #{line}" }
  exit 1
end

# Test the specific Patlang code that should trigger division by zero
test_code = <<~PATLANG
make a function called divide takes: x, y {
  return x / y
}
call divide(10, 0)
PATLANG

puts ""
puts "Testing Patlang code:"
puts test_code
puts ""

begin
  # Try to find a parse_and_evaluate method or similar
  if defined?(parse_and_evaluate)
    puts "Using parse_and_evaluate method..."
    result = parse_and_evaluate(test_code)
    puts "❌ UNEXPECTED: Code executed without error. Result: #{result}"
    
  elsif defined?(PatlangEvaluator)
    puts "Using PatlangEvaluator class..."
    evaluator = PatlangEvaluator.new
    result = evaluator.evaluate(test_code)
    puts "❌ UNEXPECTED: Code executed without error. Result: #{result}"
    
  else
    puts "❌ Cannot find evaluation method"
    puts "Available constants:"
    Object.constants.select { |c| c.to_s.include?('Patlang') }.each do |const|
      puts "  - #{const}: #{Object.const_get(const).class}"
    end
  end
  
rescue PatlangDivisionByZeroError => e
  puts "✅ SUCCESS: PatlangDivisionByZeroError caught correctly!"
  puts "   Error message: #{e.message}"
  puts "   Error class: #{e.class}"
  puts "   Context: #{e.context if e.respond_to?(:context)}"
  
  # Validate the error message contains "Division by zero"
  if e.message.match?(/Division by zero/i)
    puts "✅ Error message validation passed: Contains 'Division by zero'"
  else
    puts "❌ Error message validation failed: Missing 'Division by zero'"
    puts "   Actual message: '#{e.message}'"
  end
  
rescue ZeroDivisionError => e
  puts "❌ FAILURE: Still getting Ruby native ZeroDivisionError!"
  puts "   Error message: #{e.message}"
  puts "   Error class: #{e.class}"
  puts "   This indicates the fix is not implemented properly"
  
rescue => e
  puts "❌ UNEXPECTED ERROR: #{e.class} - #{e.message}"
  puts "Backtrace:"
  e.backtrace[0..10].each { |line| puts "  #{line}" }
end

puts ""
puts "=" * 60
puts "VALIDATION COMPLETE"
puts "=" * 60