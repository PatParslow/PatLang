#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

puts "=== Parser Completion Check ==="
puts

# Test specific syntax patterns from the API specification

test_cases = [
  # Basic constraint syntax
  { name: "Basic type constraint", code: "constrain x :: Number" },
  { name: "Range constraint", code: "constrain age :: Number where age >= 0 and age <= 150" },
  { name: "String pattern constraint", code: "constrain email :: String where email matches /\\w+@\\w+\\.\\w+/" },
  
  # Structural constraints
  { name: "Object structure constraint", code: "constrain person :: Object { name :: String, age :: Number }" },
  
  # Goal syntax
  { name: "Simple goal", code: "goal find_answer { postcondition: answer > 0 }" },
  { name: "Goal with parameters", code: "goal solve(a, b) { precondition: a > 0, postcondition: result > 0 }" },
  { name: "Goal with strategies", code: "goal optimize { strategies: [\"heuristic\", \"brute_force\"] }" },
  
  # Logic programming
  { name: "Fact assertion", code: "fact parent(john, mary)" },
  { name: "Rule definition", code: "rule ancestor(X, Z) if parent(X, Y) and ancestor(Y, Z)" },
  { name: "Prolog rule", code: "rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z)" },
  { name: "Query", code: "query parent(X, mary)" },
  { name: "Prolog query", code: "?- parent(john, X)" },
  
  # Advanced syntax
  { name: "Pursue with args", code: "pursue find_answer(42)" },
  { name: "Type annotation", code: "x :: Number" },
  { name: "Typed assignment", code: "x: Number = 42" },
  
  # Reasoning mode
  { name: "Reasoning mode on", code: "reasoning mode on" },
  { name: "Reasoning mode off", code: "reasoning mode off" }
]

passed = 0
failed = 0

test_cases.each_with_index do |test_case, i|
  print "#{i+1}. #{test_case[:name]}: "
  
  begin
    lexer = Lexer.new(test_case[:code])
    parser = Parser.new(lexer)
    ast = parser.parse
    
    if ast && !ast.is_a?(ErrorNode)
      puts "✓ PASS - #{ast.class}"
      passed += 1
    else
      puts "✗ FAIL - ErrorNode returned"
      failed += 1
    end
  rescue => e
    puts "✗ FAIL - #{e.class}: #{e.message}"
    failed += 1
  end
end

puts
puts "=== Results ==="
puts "Passed: #{passed}/#{test_cases.length}"
puts "Failed: #{failed}/#{test_cases.length}"
puts "Success Rate: #{'%.1f' % (passed.to_f / test_cases.length * 100)}%"

if failed > 0
  puts
  puts "Parser integration is #{passed >= test_cases.length * 0.9 ? 'mostly' : 'partially'} complete."
  puts "#{failed} test cases need parser extensions."
else
  puts
  puts "Parser integration is COMPLETE! All reasoning syntax is supported."
end