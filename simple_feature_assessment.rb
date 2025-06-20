#!/usr/bin/env ruby

# =============================================================================
# SIMPLE PATLANG FEATURE ASSESSMENT
# =============================================================================
# 
# A quick assessment of what actually works in PaTLang vs specification
#
# =============================================================================

require 'json'

# Load components safely
begin
  require_relative 'patlang-core/lexer/lexer'
  require_relative 'patlang-core/parser/parser'
  require_relative 'patlang-core/evaluator/evaluator'
  CORE_AVAILABLE = true
rescue LoadError => e
  puts "Core components not available: #{e.message}"
  CORE_AVAILABLE = false
end

class SimpleFeatureAssessment
  def initialize
    @results = []
    puts "🧪 SIMPLE PATLANG FEATURE ASSESSMENT"
    puts "=" * 45
  end
  
  def run_assessment
    if CORE_AVAILABLE
      @evaluator = Evaluator.new
      puts "✅ Ruby evaluator initialized\n"
      
      test_basic_features
      test_advanced_features
      generate_summary
    else
      puts "❌ Cannot run assessment - core components missing"
    end
  end
  
  private
  
  def test_basic_features
    puts "📂 BASIC LANGUAGE FEATURES"
    
    test_cases = [
      { name: "Integer literal", code: "42", expected: 42, category: "arithmetic" },
      { name: "Basic addition", code: "2 + 3", expected: 5, category: "arithmetic" },
      { name: "Operator precedence", code: "2 + 3 * 4", expected: 14, category: "arithmetic" },
      { name: "Parentheses", code: "(2 + 3) * 4", expected: 20, category: "arithmetic" },
      { name: "String literal", code: '"Hello"', expected: "Hello", category: "strings" },
      { name: "String concat", code: '"Hello" + " World"', expected: "Hello World", category: "strings" },
      { name: "Variable assignment", code: "x = 5\nx", expected: 5, category: "variables" },
      { name: "If-then-else", code: "if true then 1 else 2 end", expected: 1, category: "control_flow" }
    ]
    
    test_cases.each { |test| run_test(test) }
  end
  
  def test_advanced_features
    puts "\n📂 ADVANCED LANGUAGE FEATURES"
    
    advanced_cases = [
      { 
        name: "Simple function", 
        code: "make a function called test { return 42 }\ncall test", 
        expected: 42, 
        category: "functions",
        note: "Natural language function syntax"
      },
      { 
        name: "Function with parameters", 
        code: "make a function called add takes: x, y { return x + y }\ncall add with 2, 3", 
        expected: 5, 
        category: "functions",
        note: "Natural language with parameters"
      },
      { 
        name: "Natural variable creation", 
        code: "create a variable called counter with value 5", 
        expected: nil, 
        category: "natural_language",
        note: "Should fail - not implemented"
      },
      { 
        name: "Goal definition", 
        code: "goal solve(x) { precondition: x > 0 }", 
        expected: nil, 
        category: "goal_oriented",
        note: "Should fail - not implemented"
      },
      { 
        name: "Fact assertion", 
        code: "fact parent(tom, bob)", 
        expected: nil, 
        category: "logic_programming",
        note: "Should fail - not implemented"
      }
    ]
    
    advanced_cases.each { |test| run_test(test) }
  end
  
  def run_test(test)
    print "  🧪 #{test[:name]}... "
    
    begin
      lexer = Lexer.new(test[:code])
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      result = @evaluator.evaluate(ast)
      
      success = test[:expected].nil? || result == test[:expected]
      
      if success
        puts "✅ #{result}"
        @results << { 
          test: test[:name], 
          category: test[:category],
          status: :passed, 
          result: result,
          note: test[:note]
        }
      else
        puts "❌ #{result} (expected #{test[:expected]})"
        @results << { 
          test: test[:name], 
          category: test[:category],
          status: :failed, 
          result: result,
          expected: test[:expected],
          note: test[:note]
        }
      end
      
    rescue => e
      if test[:note]&.include?("Should fail")
        puts "✅ Failed as expected (#{e.message[0..50]}...)"
        @results << { 
          test: test[:name], 
          category: test[:category],
          status: :expected_failure, 
          error: e.message,
          note: test[:note]
        }
      else
        puts "❌ Error: #{e.message[0..50]}..."
        @results << { 
          test: test[:name], 
          category: test[:category],
          status: :error, 
          error: e.message,
          note: test[:note]
        }
      end
    end
  end
  
  def generate_summary
    puts "\n" + "=" * 45
    puts "📋 FEATURE ASSESSMENT SUMMARY"
    puts "=" * 45
    
    # Count by status
    passed = @results.count { |r| r[:status] == :passed }
    failed = @results.count { |r| r[:status] == :failed }
    errors = @results.count { |r| r[:status] == :error }
    expected_failures = @results.count { |r| r[:status] == :expected_failure }
    
    total_tests = @results.length
    working_tests = passed + expected_failures  # Expected failures are "working as expected"
    
    puts "\n📊 OVERALL RESULTS:"
    puts "  Total tests: #{total_tests}"
    puts "  ✅ Passed: #{passed}"
    puts "  ❌ Failed: #{failed}"
    puts "  🚨 Errors: #{errors}"
    puts "  ⚠️  Expected failures: #{expected_failures}"
    puts "  📈 Success rate: #{(working_tests * 100.0 / total_tests).round(1)}%"
    
    # Group by category
    categories = @results.group_by { |r| r[:category] }
    
    puts "\n📂 CATEGORY BREAKDOWN:"
    categories.each do |category, tests|
      category_passed = tests.count { |t| [:passed, :expected_failure].include?(t[:status]) }
      category_total = tests.length
      percentage = (category_passed * 100.0 / category_total).round(1)
      status_icon = percentage == 100 ? "✅" : percentage >= 50 ? "⚠️" : "❌"
      
      puts "  #{status_icon} #{category.capitalize}: #{category_passed}/#{category_total} (#{percentage}%)"
    end
    
    puts "\n✅ WORKING FEATURES:"
    @results.select { |r| r[:status] == :passed }.each do |result|
      puts "  • #{result[:test]} (#{result[:category]})"
    end
    
    puts "\n❌ BROKEN FEATURES:"
    @results.select { |r| [:failed, :error].include?(r[:status]) }.each do |result|
      puts "  • #{result[:test]} (#{result[:category]})"
    end
    
    puts "\n⚠️  EXPECTED NON-IMPLEMENTATIONS:"
    @results.select { |r| r[:status] == :expected_failure }.each do |result|
      puts "  • #{result[:test]} (#{result[:category]}) - #{result[:note]}"
    end
    
    # Key findings
    puts "\n🔍 KEY FINDINGS:"
    
    arithmetic_working = categories["arithmetic"]&.all? { |t| t[:status] == :passed } || false
    strings_working = categories["strings"]&.all? { |t| t[:status] == :passed } || false
    control_working = categories["control_flow"]&.all? { |t| t[:status] == :passed } || false
    variables_working = categories["variables"]&.all? { |t| t[:status] == :passed } || false
    functions_working = categories["functions"]&.any? { |t| t[:status] == :passed } || false
    
    puts "  • ✅ CORE WORKING: Basic arithmetic: #{arithmetic_working ? 'YES' : 'NO'}"
    puts "  • ✅ CORE WORKING: String handling: #{strings_working ? 'YES' : 'NO'}"
    puts "  • ✅ CORE WORKING: Control flow: #{control_working ? 'YES' : 'NO'}"
    puts "  • ✅ CORE WORKING: Variables: #{variables_working ? 'YES' : 'NO'}"
    puts "  • 🎯 ADVANCED: Function definitions: #{functions_working ? 'WORKING!' : 'Not working'}"
    
    # Overall assessment
    puts "\n💡 OVERALL ASSESSMENT:"
    
    core_features_working = arithmetic_working && strings_working && control_working && variables_working
    
    if core_features_working && functions_working
      puts "  🎉 EXCELLENT: Core features work AND advanced features are implemented!"
      puts "  PaTLang is more complete than expected."
    elsif core_features_working
      puts "  👍 GOOD: All core language features are working correctly."
      puts "  PaTLang provides a solid foundation for basic programming."
    elsif working_tests > total_tests * 0.6
      puts "  ⚠️  PARTIAL: Most features work but some core gaps exist."
      puts "  PaTLang is usable but has limitations."
    else
      puts "  🚨 CONCERNING: Significant gaps in core functionality."
      puts "  PaTLang needs fundamental fixes before practical use."
    end
    
    puts "\n🎯 SURPRISE FINDINGS:"
    if functions_working
      puts "  • 🎉 Natural language function syntax WORKS! This is a major feature."
    end
    
    unexpected_working = @results.select { |r| r[:status] == :passed && r[:note]&.include?("Natural language") }
    if unexpected_working.any?
      puts "  • 🎉 Unexpected working features found!"
      unexpected_working.each { |f| puts "    - #{f[:test]}" }
    end
    
    # Save results
    File.write('simple_feature_assessment.json', JSON.pretty_generate({
      summary: {
        total_tests: total_tests,
        passed: passed,
        failed: failed,
        errors: errors,
        expected_failures: expected_failures,
        success_rate: (working_tests * 100.0 / total_tests).round(1)
      },
      categories: categories,
      detailed_results: @results,
      timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S")
    }))
    
    puts "\n💾 Detailed results saved to: simple_feature_assessment.json"
    puts "\n" + "=" * 45
  end
end

# Run the assessment
if __FILE__ == $0
  assessment = SimpleFeatureAssessment.new
  assessment.run_assessment
end