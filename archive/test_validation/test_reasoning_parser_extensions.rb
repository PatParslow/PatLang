#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'

# Test script to validate reasoning parser extensions
class ReasoningParserTest
  def initialize
    @test_count = 0
    @passed_count = 0
  end
  
  def test(description, &block)
    @test_count += 1
    print "#{@test_count}. #{description}... "
    
    begin
      result = yield
      if result
        puts "PASS"
        @passed_count += 1
      else
        puts "FAIL"
      end
    rescue => e
      puts "ERROR: #{e.message}"
      puts e.backtrace.first(3).join("\n")
    end
  end
  
  def summary
    puts "\n" + "="*50
    puts "Results: #{@passed_count}/#{@test_count} tests passed"
    puts "="*50
  end
  
  def parse_code(code)
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    parser.parse
  end
  
  def run_tests
    puts "Testing Reasoning Parser Extensions"
    puts "="*50
    
    # Test 1: Type Constraint Parsing
    test "Parse basic type constraint" do
      code = "constrain x :: Number"
      ast = parse_code(code)
      ast.is_a?(TypeConstraintNode) && 
        ast.variable == :x && 
        ast.constraint_type == "Number"
    end
    
    # Test 2: Type Constraint with Where Clause
    test "Parse type constraint with where clause" do
      code = "constrain x :: Number where x > 0"
      ast = parse_code(code)
      ast.is_a?(TypeConstraintNode) && 
        ast.variable == :x && 
        ast.constraint_type == "Number" &&
        !ast.conditions.nil?
    end
    
    # Test 3: Type Constraint with Dotted Variable
    test "Parse type constraint with dotted variable" do
      code = "constrain obj.field :: String"
      ast = parse_code(code)
      ast.is_a?(TypeConstraintNode) && 
        ast.variable == "obj.field" && 
        ast.constraint_type == "String"
    end
    
    # Test 4: Goal Declaration Parsing
    test "Parse basic goal declaration" do
      code = "goal find_maximum(list) { postcondition: result > 0 }"
      ast = parse_code(code)
      ast.is_a?(GoalNode) && 
        ast.description == "find_maximum"
    end
    
    # Test 5: Logic Rule with 'if' syntax
    test "Parse logic rule with 'if' syntax" do
      code = "rule grandparent(X, Z) if parent(X, Y) and parent(Y, Z)"
      ast = parse_code(code)
      ast.is_a?(LogicRuleNode) && 
        !ast.head.nil? && 
        !ast.body.nil?
    end
    
    # Test 6: Fact Declaration
    test "Parse fact declaration" do
      code = "fact parent(john, mary)"
      ast = parse_code(code)
      ast.is_a?(LogicRuleNode) && 
        !ast.head.nil? && 
        ast.body.nil? &&
        ast.rule_type == :fact
    end
    
    # Test 7: Prolog-style Query
    test "Parse Prolog-style query" do
      code = "?- parent(john, mary)"
      ast = parse_code(code)
      ast.is_a?(QueryNode) && 
        !ast.goal_term.nil? &&
        ast.query_type == :prolog
    end
    
    # Test 8: Traditional Query
    test "Parse traditional query" do
      code = "query likes(X, bob)"
      ast = parse_code(code)
      ast.is_a?(QueryNode) && 
        !ast.goal_term.nil?
    end
    
    # Test 9: Complex Goal with Multiple Attributes
    test "Parse complex goal with strategies" do
      code = "goal solve_puzzle { precondition: puzzle != nil, postcondition: solved == true, strategy: backtrack }"
      ast = parse_code(code)
      ast.is_a?(GoalNode) && 
        ast.description == "solve_puzzle"
    end
    
    # Test 10: Error Handling - Invalid Constraint
    test "Handle invalid constraint syntax gracefully" do
      code = "constrain x"  # Missing type
      ast = parse_code(code)
      ast.is_a?(ErrorNode) || ast.nil?
    end
    
    summary
  end
end

# Run the tests
tester = ReasoningParserTest.new
tester.run_tests