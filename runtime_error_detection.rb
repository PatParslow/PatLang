#!/usr/bin/env ruby

# Runtime error detection for core infrastructure
require 'timeout'

puts "🔍 RUNTIME ERROR DETECTION"
puts "=" * 50

def test_require_and_load(description, &block)
  print "#{description}... "
  begin
    Timeout::timeout(5) do
      result = block.call
      puts "✅ OK"
      return true
    end
  rescue Timeout::Error
    puts "⏰ TIMEOUT"
    return false
  rescue => e
    puts "❌ ERROR: #{e.class} - #{e.message}"
    puts "   #{e.backtrace.first}" if e.backtrace
    return false
  end
end

errors_found = []

# Test core infrastructure loading
puts "\n📁 CORE INFRASTRUCTURE TESTS"
puts "-" * 30

success = test_require_and_load("Loading main Patlang module") do
  require_relative 'src/patlang'
  true
end
errors_found << "Patlang module load failed" unless success

success = test_require_and_load("Loading lexer") do
  require_relative 'src/lexer'
  true
end
errors_found << "Lexer load failed" unless success

success = test_require_and_load("Loading parser") do
  require_relative 'src/parser'
  true
end
errors_found << "Parser load failed" unless success

success = test_require_and_load("Loading evaluator") do
  require_relative 'src/evaluator'
  true
end
errors_found << "Evaluator load failed" unless success

success = test_require_and_load("Loading test helper") do
  require_relative 'test/helpers/test_helper'
  true
end
errors_found << "Test helper load failed" unless success

# Test basic functionality
puts "\n🧪 BASIC FUNCTIONALITY TESTS"
puts "-" * 30

success = test_require_and_load("Creating lexer instance") do
  lexer = Lexer.new("1 + 1")
  tokens = lexer.tokenize
  tokens.length > 0
end
errors_found << "Lexer tokenization failed" unless success

success = test_require_and_load("Creating parser instance") do
  lexer = Lexer.new("1 + 1")
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.parse
  !ast.nil?
end
errors_found << "Parser parsing failed" unless success

success = test_require_and_load("Creating evaluator instance") do
  evaluator = Evaluator.new
  !evaluator.nil?
end
errors_found << "Evaluator creation failed" unless success

success = test_require_and_load("Basic evaluation") do
  result = Patlang.evaluate("1 + 1")
  result == 2
end
errors_found << "Basic evaluation failed" unless success

# Test reasoning components
puts "\n🧠 REASONING COMPONENTS TESTS"  
puts "-" * 30

reasoning_components = [
  ['facts_database', 'src/reasoning/facts_database'],
  ['goal_system', 'src/reasoning/goal_system'],
  ['unification_engine', 'src/reasoning/unification_engine'],
  ['reasoning_coordinator', 'src/reasoning/reasoning_coordinator'],
  ['form_validator', 'src/reasoning/form_validator'],
  ['type_constraint', 'src/reasoning/type_constraint']
]

reasoning_components.each do |name, path|
  success = test_require_and_load("Loading #{name}") do
    require_relative path
    true
  end
  errors_found << "#{name} load failed" unless success
end

# Test object model
puts "\n🏗️ OBJECT MODEL TESTS"
puts "-" * 30

object_components = [
  ['patlang_object', 'src/object_model/patlang_object'],
  ['string_object', 'src/object_model/string_object'],
  ['number_object', 'src/object_model/number_object'],
  ['event_system', 'src/object_model/event_system']
]

object_components.each do |name, path|
  success = test_require_and_load("Loading #{name}") do
    require_relative path
    true
  end
  errors_found << "#{name} load failed" unless success
end

# Test representative test files
puts "\n🧪 REPRESENTATIVE TEST FILES"
puts "-" * 30

test_files = [
  'test/infrastructure/test_lexer.rb',
  'test/infrastructure/test_parser.rb', 
  'test/patlang_language/test_evaluator.rb'
]

test_files.each do |test_file|
  success = test_require_and_load("Loading #{File.basename(test_file)}") do
    require_relative test_file
    true
  end
  errors_found << "#{test_file} load failed" unless success
end

# Summary
puts "\n" + "=" * 50
puts "📊 RUNTIME ERROR DETECTION SUMMARY"
puts "=" * 50

if errors_found.empty?
  puts "✅ ALL TESTS PASSED: No runtime errors detected"
  puts "✅ Core infrastructure is loading and functioning properly"
  puts "✅ Ready for comprehensive test execution"
else
  puts "❌ ERRORS DETECTED (#{errors_found.length}):"
  errors_found.each_with_index do |error, i|
    puts "   #{i+1}. #{error}"
  end
end

puts "\n🎯 NEXT STEPS"
puts "=" * 15

if errors_found.empty?
  puts "✅ Infrastructure ready - proceed with test failure analysis"
  exit 0
else
  puts "❌ Fix runtime errors before proceeding with test analysis"
  exit 1
end