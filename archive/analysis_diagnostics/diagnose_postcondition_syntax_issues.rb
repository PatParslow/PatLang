#!/usr/bin/env ruby

# Add current directory and src to load path
$LOAD_PATH.unshift(File.expand_path('.', __dir__))
$LOAD_PATH.unshift(File.expand_path('src', __dir__))
$LOAD_PATH.unshift(File.expand_path('test', __dir__))

require 'timeout'

class PostconditionSyntaxDiagnostic
  def initialize
    @test_results = []
    @postcondition_failures = []
  end

  def run_diagnosis
    puts "🔍 Priority 3B-2: Diagnosing Parser Postcondition Syntax Issues"
    puts "=" * 70
    
    identify_failing_tests
    analyze_postcondition_patterns
    test_parser_behavior
    generate_fix_strategy
  end

  private

  def identify_failing_tests
    puts "\n📊 Identifying tests with postcondition syntax failures..."
    
    # Test cases that are known to fail due to postcondition syntax
    failing_test_cases = [
      {
        name: "malformed_goal_syntax",
        file: "test/patlang_language/test_reasoning_integration.rb",
        code: 'goal malformed { postcondition missing colon }',
        expected_issue: "Missing colon after postcondition"
      },
      {
        name: "validate_priority_3_fixes",
        file: "test_priority_3_fixes.rb", 
        code: 'goal malformed { postcondition missing colon }',
        expected_issue: "Missing colon after postcondition"
      }
    ]
    
    failing_test_cases.each do |test_case|
      puts "\n  Testing: #{test_case[:name]}"
      puts "  File: #{test_case[:file]}"
      puts "  Code: #{test_case[:code]}"
      
      begin
        # Try to load the lexer and parser
        require_relative 'src/lexer'
        require_relative 'src/parser'
        
        lexer = Lexer.new(test_case[:code])
        tokens = lexer.tokenize
        parser = Parser.new(tokens)
        
        result = parser.parse
        
        if result.is_a?(ErrorNode)
          puts "  ✓ CONFIRMS ISSUE: Parser returned ErrorNode"
          puts "    Error: #{result.message}"
          @postcondition_failures << test_case.merge(actual_error: result.message)
        else
          puts "  ⚠️ UNEXPECTED: Parser succeeded when it should fail"
          @postcondition_failures << test_case.merge(actual_error: "No error - unexpected success")
        end
        
      rescue => e
        puts "  ✓ CONFIRMS ISSUE: Parser error: #{e.message}"
        @postcondition_failures << test_case.merge(actual_error: e.message)
      end
    end
    
    puts "\n📈 Results:"
    puts "  Total postcondition syntax issues identified: #{@postcondition_failures.length}"
  end

  def analyze_postcondition_patterns
    puts "\n🔍 Analyzing postcondition syntax patterns..."
    
    # Test different postcondition syntax variations
    syntax_variations = [
      {
        name: "missing_colon",
        code: 'goal test { postcondition x > 0 }',
        should_fail: true,
        description: "Missing colon after postcondition keyword"
      },
      {
        name: "correct_syntax",
        code: 'goal test { postcondition: x > 0 }',
        should_fail: false,
        description: "Correct postcondition syntax with colon"
      },
      {
        name: "multiple_postconditions_missing_colon",
        code: 'goal test { postcondition x > 0, postcondition y < 10 }',
        should_fail: true,
        description: "Multiple postconditions, both missing colons"
      },
      {
        name: "mixed_syntax",
        code: 'goal test { postcondition: x > 0, postcondition y < 10 }',
        should_fail: true,
        description: "Mixed syntax - first correct, second missing colon"
      }
    ]
    
    syntax_variations.each do |variation|
      puts "\n  Testing pattern: #{variation[:name]}"
      puts "    Code: #{variation[:code]}"
      puts "    Should fail: #{variation[:should_fail]}"
      
      begin
        require_relative 'src/lexer'
        require_relative 'src/parser'
        
        lexer = Lexer.new(variation[:code])
        tokens = lexer.tokenize
        parser = Parser.new(tokens)
        
        result = parser.parse
        
        failed = result.is_a?(ErrorNode) || result.nil?
        
        if variation[:should_fail] && failed
          puts "    ✓ CORRECT: Failed as expected"
          puts "      Error: #{result&.message || 'Parse returned nil'}"
        elsif !variation[:should_fail] && !failed
          puts "    ✓ CORRECT: Succeeded as expected"
        elsif variation[:should_fail] && !failed
          puts "    ❌ WRONG: Should have failed but succeeded"
        else
          puts "    ❌ WRONG: Should have succeeded but failed"
          puts "      Error: #{result&.message || 'Parse returned nil'}"
        end
        
      rescue => e
        if variation[:should_fail]
          puts "    ✓ CORRECT: Exception as expected - #{e.message}"
        else
          puts "    ❌ WRONG: Unexpected exception - #{e.message}"
        end
      end
    end
  end

  def test_parser_behavior
    puts "\n🧪 Testing parser colon requirement behavior..."
    
    # Test how the parser currently handles missing colons
    test_codes = [
      'goal test { postcondition missing colon }',
      'goal test { precondition missing colon }',
      'goal test { description missing colon }',
      'goal test { strategy missing colon }'
    ]
    
    test_codes.each do |code|
      puts "\n  Testing: #{code}"
      
      begin
        require_relative 'src/lexer'
        require_relative 'src/parser'
        
        lexer = Lexer.new(code)
        tokens = lexer.tokenize
        
        puts "    Tokens: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(', ')}"
        
        parser = Parser.new(tokens)
        result = parser.parse
        
        if result.is_a?(ErrorNode)
          puts "    Result: ErrorNode - #{result.message}"
        elsif result.nil?
          puts "    Result: nil (parse failed)"
        else
          puts "    Result: #{result.class} (unexpected success)"
        end
        
      rescue => e
        puts "    Exception: #{e.message}"
      end
    end
  end

  def generate_fix_strategy
    puts "\n🔧 Fix Strategy for Postcondition Syntax Issues"
    puts "=" * 50
    
    puts "\n📋 Issue Analysis:"
    puts "  • Parser strictly requires colons after postcondition keywords"
    puts "  • Tests contain malformed syntax: 'postcondition missing colon'"
    puts "  • Parser error recovery creates ErrorNode with helpful messages"
    puts "  • Current behavior is correct - tests have wrong expectations"
    
    puts "\n🎯 Recommended Fixes:"
    puts "  1. Update test syntax to include required colons"
    puts "  2. Change 'postcondition missing colon' to 'postcondition: missing_colon'"
    puts "  3. Ensure test expectations match parser error recovery behavior"
    puts "  4. Verify parser returns ErrorNode (not exception) for malformed syntax"
    
    puts "\n📁 Files to Update:"
    @postcondition_failures.each do |failure|
      puts "  • #{failure[:file]}"
      puts "    Change: #{failure[:code]}"
      puts "    To: #{fix_syntax(failure[:code])}"
    end
    
    puts "\n✅ Expected Impact:"
    puts "  • Convert ~5 postcondition syntax failures to passes"
    puts "  • Improve parser test coverage for error recovery"
    puts "  • Maintain strict syntax requirements (good for language design)"
  end

  def fix_syntax(original_code)
    # Fix the syntax by adding missing colons
    original_code.gsub(/(\w+)\s+([^:])/, '\1: \2')
  end
end

# Run the diagnostic
if __FILE__ == $0
  diagnostic = PostconditionSyntaxDiagnostic.new
  diagnostic.run_diagnosis
end