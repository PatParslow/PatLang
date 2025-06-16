#!/usr/bin/env ruby

# Diagnostic script to identify assert_raises exception type mismatches
# This will help us identify which tests expect ParseError but get other exceptions

require_relative 'test/test_helper'
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

class AssertRaisesDiagnostic
  def initialize
    @mismatches = []
    @test_cases = []
    setup_test_cases
  end

  def setup_test_cases
    # Based on the search results, let's test the key scenarios
    
    # Test case 1: Reasoning integration malformed goal
    @test_cases << {
      name: "reasoning_integration_malformed_goal",
      file: "test/patlang_language/test_reasoning_integration.rb",
      line: 348,
      code: <<~PATLANG,
        goal malformed {
          postcondition missing colon
        }
      PATLANG
      expected: ParseError,
      context: :reasoning_mode
    }

    # Test case 2: Another reasoning integration case
    @test_cases << {
      name: "reasoning_integration_another_case", 
      file: "test/patlang_language/test_reasoning_integration.rb",
      line: 330,
      code: "goal test_goal {\n  invalid syntax here\n}",
      expected: ParseError,
      context: :reasoning_mode
    }

    # Test case 3: Parser branch coverage - unbalanced parens
    @test_cases << {
      name: "parser_unbalanced_parens_open",
      file: "test/infrastructure/test_parser_branch_coverage.rb", 
      line: 111,
      code: "(2 + 3",
      expected: ParseError,
      context: :normal
    }

    # Test case 4: Parser branch coverage - unbalanced parens close
    @test_cases << {
      name: "parser_unbalanced_parens_close",
      file: "test/infrastructure/test_parser_branch_coverage.rb",
      line: 117, 
      code: "2 + 3)",
      expected: ParseError,
      context: :normal
    }

    # Test case 5: Goal without body
    @test_cases << {
      name: "goal_without_body",
      file: "test/infrastructure/test_parser_branch_coverage.rb",
      line: 263,
      code: "goal test_goal",
      expected: ParseError,
      context: :reasoning_mode
    }

    # Test case 6: Goal without name
    @test_cases << {
      name: "goal_without_name", 
      file: "test/infrastructure/test_parser_branch_coverage.rb",
      line: 270,
      code: "goal { condition }",
      expected: ParseError,
      context: :reasoning_mode
    }

    # Test case 7: Lexer error scenarios
    @test_cases << {
      name: "lexer_unterminated_string",
      file: "test/infrastructure/test_lexer_error_scenarios.rb",
      line: 20,
      code: '"unterminated string',
      expected: ParseError,
      context: :normal
    }

    # Test case 8: Type constraint parser errors
    @test_cases << {
      name: "type_constraint_invalid",
      file: "test/infrastructure/test_type_constraint_parser.rb", 
      line: 369,
      code: "constraint invalid_syntax {",
      expected: ParseError,
      context: :normal
    }
  end

  def run_diagnostic
    puts "🔍 Diagnosing assert_raises exception type mismatches..."
    puts "=" * 60
    
    @test_cases.each do |test_case|
      diagnose_test_case(test_case)
    end
    
    puts "\n📊 SUMMARY"
    puts "=" * 60
    puts "Total test cases: #{@test_cases.length}"
    puts "Mismatches found: #{@mismatches.length}"
    
    if @mismatches.any?
      puts "\n🚨 EXCEPTION TYPE MISMATCHES:"
      @mismatches.each do |mismatch|
        puts "  ❌ #{mismatch[:name]}"
        puts "     Expected: #{mismatch[:expected]}"
        puts "     Actual: #{mismatch[:actual]}"
        puts "     File: #{mismatch[:file]}:#{mismatch[:line]}"
        puts "     Message: #{mismatch[:message]}"
        puts
      end
    else
      puts "✅ No mismatches found - all exception types match expectations"
    end
  end

  private

  def diagnose_test_case(test_case)
    print "Testing #{test_case[:name]}... "
    
    begin
      if test_case[:context] == :reasoning_mode
        enable_reasoning_mode if respond_to?(:enable_reasoning_mode)
      end
      
      actual_exception = nil
      begin
        if test_case[:code].include?('goal') || test_case[:context] == :reasoning_mode
          # Use evaluator for reasoning mode tests
          evaluate_patlang_code(test_case[:code]) if respond_to?(:evaluate_patlang_code)
        elsif test_case[:code].include?('constraint')
          # Handle type constraint parsing
          lexer = Lexer.new(test_case[:code])
          parser = Parser.new(lexer)
          parser.parse
        else
          # Use lexer/parser for normal syntax tests
          lexer = Lexer.new(test_case[:code])
          if test_case[:name].include?('lexer')
            lexer.tokenize
          else
            parser = Parser.new(lexer)
            parser.parse
          end
        end
        
        # If we get here, no exception was thrown
        puts "❌ NO EXCEPTION (expected #{test_case[:expected]})"
        @mismatches << {
          name: test_case[:name],
          expected: test_case[:expected],
          actual: "No Exception",
          file: test_case[:file],
          line: test_case[:line],
          message: "Expected exception but code executed successfully"
        }
        
      rescue => e
        actual_exception = e.class
        actual_message = e.message
        
        if actual_exception == test_case[:expected]
          puts "✅ MATCH (#{actual_exception})"
        else
          puts "❌ MISMATCH (expected #{test_case[:expected]}, got #{actual_exception})"
          @mismatches << {
            name: test_case[:name],
            expected: test_case[:expected],
            actual: actual_exception,
            file: test_case[:file],
            line: test_case[:line],
            message: actual_message
          }
        end
      end
      
    rescue => e
      puts "❌ DIAGNOSTIC ERROR: #{e.class}: #{e.message}"
    end
  end

  # Stub methods in case they're not available
  def enable_reasoning_mode
    # This would normally enable reasoning mode in tests
  end

  def evaluate_patlang_code(code)
    # This would normally evaluate patlang code
    # For now, let's try to parse it directly
    lexer = Lexer.new(code)
    parser = Parser.new(lexer) 
    parser.parse
  end
end

# Run the diagnostic
diagnostic = AssertRaisesDiagnostic.new
diagnostic.run_diagnostic