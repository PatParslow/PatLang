#!/usr/bin/env ruby

# Simple require test for unknown error files
puts "🔍 TESTING REQUIRE FAILURES"
puts "=" * 40

test_files = [
  "test/infrastructure/test_reasoning_coordinator.rb",
  "test/ruby_implementation/test_string_operations.rb", 
  "test/patlang_language/test_evaluator_error_handling.rb",
  "test/helpers/test_constants.rb"
]

test_files.each do |file|
  puts "\n📂 Testing: #{file}"
  
  begin
    puts "  🔄 Attempting to require..."
    require_relative file
    puts "  ✅ SUCCESS: File loaded successfully"
  rescue LoadError => e
    puts "  ❌ LoadError: #{e.message}"
    puts "     📝 Missing file or wrong path"
  rescue NameError => e
    puts "  ❌ NameError: #{e.message}"
    puts "     📝 Missing class or constant definition"
  rescue => e
    puts "  ❌ #{e.class}: #{e.message}"
    puts "     📝 Other error type"
    puts "     🔍 Backtrace: #{e.backtrace[0..2].join("\n     ")}"
  end
end

puts "\n🎯 DIRECT FILE CHECKS"
puts "=" * 30

# Check if key source files exist
source_files = [
  "src/reasoning/reasoning_coordinator.rb",
  "src/evaluator.rb",
  "src/lexer.rb",
  "src/parser.rb"
]

source_files.each do |file|
  exists = File.exist?(file)
  puts "#{exists ? '✅' : '❌'} #{file} #{exists ? 'exists' : 'MISSING'}"
end