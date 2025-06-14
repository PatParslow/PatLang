#!/usr/bin/env ruby

# Comprehensive Test Error Analysis
# Analyzes current test failures to create systematic diagnosis report

require 'json'

class TestErrorAnalyzer
  def initialize
    @error_categories = {
      'LocalJumpError: unexpected return' => {
        count: 0,
        description: 'Critical parser error - return statement in wrong context',
        severity: 'CRITICAL',
        root_cause: 'Token resolver return statement in timeout protection block',
        affected_components: [],
        sample_errors: []
      },
      'NoMethodError: undefined method' => {
        count: 0,
        description: 'Missing method implementations',
        severity: 'HIGH',
        root_cause: 'Method stubs not implemented or incorrect method calls',
        affected_components: [],
        sample_errors: []
      },
      'ArgumentError: wrong number of arguments' => {
        count: 0,
        description: 'Constructor/method signature mismatches',
        severity: 'HIGH',
        root_cause: 'Interface changes not propagated to all usage sites',
        affected_components: [],
        sample_errors: []
      },
      'Expected vs Actual failures' => {
        count: 0,
        description: 'Logic errors producing wrong results',
        severity: 'MEDIUM',
        root_cause: 'Implementation logic not matching expected behavior',
        affected_components: [],
        sample_errors: []
      },
      'Exception type mismatches' => {
        count: 0,
        description: 'Tests expecting different exception types',
        severity: 'MEDIUM',
        root_cause: 'Error handling changes not reflected in tests',
        affected_components: [],
        sample_errors: []
      },
      'Nil/null reference errors' => {
        count: 0,
        description: 'Unexpected nil values',
        severity: 'MEDIUM',
        root_cause: 'Missing initialization or nil guard failures',
        affected_components: [],
        sample_errors: []
      },
      'Coverage/timeout related' => {
        count: 0,
        description: 'Test infrastructure issues',
        severity: 'LOW',
        root_cause: 'Test configuration or infrastructure problems',
        affected_components: [],
        sample_errors: []
      }
    }
    
    @component_mapping = {
      'TestFlexibleFunctionSyntax' => 'Parser/Function Definition',
      'TestParserBranchCoverage' => 'Parser Core',
      'TestGoalResolutionEngine' => 'Reasoning/Goal System',
      'TestErrorHandlingCoverage' => 'Error Handling',
      'TestIntegration' => 'End-to-End Integration',
      'TestPerformanceOptimization' => 'Performance Systems',
      'TestEvaluator' => 'Expression Evaluator',
      'TestUnificationEngine' => 'Reasoning/Unification',
      'TestFactsDatabase' => 'Reasoning/Facts',
      'TestObjectModel' => 'Object Model',
      'TestTypeConstraints' => 'Type System'
    }
    
    @total_tests = 0
    @total_failures = 0
    @total_errors = 0
    @total_skips = 0
  end
  
  def analyze_test_output(output_text)
    lines = output_text.split("\n")
    
    # Extract summary statistics
    summary_line = lines.find { |line| line.match(/\d+ runs, \d+ assertions, \d+ failures, \d+ errors/) }
    if summary_line
      matches = summary_line.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors(?:, (\d+) skips)?/)
      if matches
        @total_tests = matches[1].to_i
        @total_failures = matches[3].to_i
        @total_errors = matches[4].to_i
        @total_skips = matches[5]&.to_i || 0
      end
    end
    
    # Analyze individual test failures
    current_test = nil
    current_error_text = []
    in_error = false
    
    lines.each do |line|
      # Detect test failure/error start
      if line.match(/^\d+\) (Error|Failure):/)
        # Process previous error if exists
        process_error(current_test, current_error_text.join("\n")) if current_test && !current_error_text.empty?
        
        # Start new error
        current_test = extract_test_name(line)
        current_error_text = [line]
        in_error = true
      elsif in_error
        # Continue collecting error text
        current_error_text << line
        
        # Stop at next test or end of errors
        if line.match(/^\d+\) (Error|Failure):/) || line.match(/^\d+ runs, \d+ assertions/)
          process_error(current_test, current_error_text[0..-2].join("\n")) if current_test
          current_test = nil
          current_error_text = []
          in_error = false
        end
      end
    end
    
    # Process final error if exists
    process_error(current_test, current_error_text.join("\n")) if current_test && !current_error_text.empty?
  end
  
  def extract_test_name(line)
    # Extract test class and method from error line
    match = line.match(/^\d+\) (?:Error|Failure):\s*([^#]+)#?([^:]*):?/)
    return match[1].strip if match
    nil
  end
  
  def process_error(test_name, error_text)
    return unless test_name && !error_text.empty?
    
    # Categorize the error
    category = categorize_error(error_text)
    
    if @error_categories[category]
      @error_categories[category][:count] += 1
      
      # Map to component
      component = map_to_component(test_name)
      @error_categories[category][:affected_components] << component unless @error_categories[category][:affected_components].include?(component)
      
      # Store sample error (limit to 3 per category)
      if @error_categories[category][:sample_errors].length < 3
        @error_categories[category][:sample_errors] << {
          test: test_name,
          error: error_text.lines[0..5].join.strip
        }
      end
    end
  end
  
  def categorize_error(error_text)
    case error_text
    when /LocalJumpError.*unexpected return/
      'LocalJumpError: unexpected return'
    when /NoMethodError.*undefined method/
      'NoMethodError: undefined method'
    when /ArgumentError.*wrong number of arguments/
      'ArgumentError: wrong number of arguments'
    when /--- expected.*\+\+\+ actual/
      'Expected vs Actual failures'
    when /exception expected, not/
      'Exception type mismatches'
    when /Expected.*nil.*to/
      'Nil/null reference errors'
    else
      'Coverage/timeout related'
    end
  end
  
  def map_to_component(test_name)
    @component_mapping.each do |pattern, component|
      return component if test_name.include?(pattern)
    end
    'Unknown Component'
  end
  
  def generate_report
    report = {
      summary: {
        total_tests: @total_tests,
        total_failures: @total_failures,
        total_errors: @total_errors,
        total_skips: @total_skips,
        success_rate: calculate_success_rate,
        analysis_timestamp: Time.now.to_s
      },
      error_categories: @error_categories,
      prioritized_fixes: generate_prioritized_fixes,
      component_impact: generate_component_impact,
      recommendations: generate_recommendations
    }
    
    report
  end
  
  def calculate_success_rate
    return 0 if @total_tests == 0
    successful = @total_tests - @total_failures - @total_errors
    ((successful.to_f / @total_tests) * 100).round(2)
  end
  
  def generate_prioritized_fixes
    fixes = []
    
    @error_categories.each do |category, data|
      next if data[:count] == 0
      
      priority_score = calculate_priority_score(data)
      fixes << {
        category: category,
        count: data[:count],
        severity: data[:severity],
        priority_score: priority_score,
        root_cause: data[:root_cause],
        affected_components: data[:affected_components].uniq
      }
    end
    
    fixes.sort_by { |fix| -fix[:priority_score] }
  end
  
  def calculate_priority_score(data)
    severity_weight = {
      'CRITICAL' => 100,
      'HIGH' => 50,
      'MEDIUM' => 25,
      'LOW' => 10
    }
    
    base_score = severity_weight[data[:severity]] || 10
    count_multiplier = [data[:count], 10].min # Cap at 10x multiplier
    component_impact = data[:affected_components].uniq.length
    
    (base_score * count_multiplier * (1 + component_impact * 0.1)).round
  end
  
  def generate_component_impact
    component_errors = Hash.new(0)
    
    @error_categories.each do |category, data|
      data[:affected_components].each do |component|
        component_errors[component] += data[:count]
      end
    end
    
    component_errors.sort_by { |k, v| -v }.to_h
  end
  
  def generate_recommendations
    recommendations = []
    
    # Critical: LocalJumpError fix
    if @error_categories['LocalJumpError: unexpected return'][:count] > 0
      recommendations << {
        priority: 'CRITICAL',
        title: 'Fix Token Resolver Return Statement',
        description: 'Replace return statement in timeout protection block with proper value assignment',
        impact: "Fixes #{@error_categories['LocalJumpError: unexpected return'][:count]} test failures",
        effort: 'LOW',
        file: 'src/parser/token_resolver.rb:237'
      }
    end
    
    # High: Method implementations
    if @error_categories['NoMethodError: undefined method'][:count] > 0
      recommendations << {
        priority: 'HIGH',
        title: 'Implement Missing Methods',
        description: 'Add missing method implementations and fix method calls',
        impact: "Fixes #{@error_categories['NoMethodError: undefined method'][:count]} test failures",
        effort: 'MEDIUM',
        components: @error_categories['NoMethodError: undefined method'][:affected_components]
      }
    end
    
    # High: Constructor signatures
    if @error_categories['ArgumentError: wrong number of arguments'][:count] > 0
      recommendations << {
        priority: 'HIGH',
        title: 'Fix Constructor/Method Signatures',
        description: 'Update constructor calls to match current signatures',
        impact: "Fixes #{@error_categories['ArgumentError: wrong number of arguments'][:count]} test failures",
        effort: 'LOW',
        components: @error_categories['ArgumentError: wrong number of arguments'][:affected_components]
      }
    end
    
    recommendations
  end
  
  def save_report(filename = 'COMPREHENSIVE_TEST_ERROR_ANALYSIS.json')
    report = generate_report
    File.write(filename, JSON.pretty_generate(report))
    puts "📊 Comprehensive error analysis saved to #{filename}"
    report
  end
  
  def print_summary
    report = generate_report
    
    puts "\n" + "="*80
    puts "🪲 COMPREHENSIVE TEST ERROR ANALYSIS REPORT"
    puts "="*80
    
    puts "\n📊 TEST EXECUTION SUMMARY:"
    puts "   Total Tests: #{report[:summary][:total_tests]}"
    puts "   Failures: #{report[:summary][:total_failures]}"
    puts "   Errors: #{report[:summary][:total_errors]}"
    puts "   Skips: #{report[:summary][:total_skips]}"
    puts "   Success Rate: #{report[:summary][:success_rate]}%"
    
    puts "\n🎯 PRIORITIZED ERROR CATEGORIES:"
    report[:prioritized_fixes].each_with_index do |fix, index|
      puts "   #{index + 1}. #{fix[:category]} (#{fix[:severity]})"
      puts "      Count: #{fix[:count]} failures"
      puts "      Priority Score: #{fix[:priority_score]}"
      puts "      Root Cause: #{fix[:root_cause]}"
      puts "      Components: #{fix[:affected_components].join(', ')}"
      puts
    end
    
    puts "🏗️ COMPONENT IMPACT ANALYSIS:"
    report[:component_impact].each do |component, count|
      puts "   #{component}: #{count} errors"
    end
    
    puts "\n💡 TOP RECOMMENDATIONS:"
    report[:recommendations].take(3).each_with_index do |rec, index|
      puts "   #{index + 1}. [#{rec[:priority]}] #{rec[:title]}"
      puts "      #{rec[:description]}"
      puts "      Impact: #{rec[:impact]}"
      puts "      Effort: #{rec[:effort]}"
      puts
    end
    
    puts "="*80
    puts "Analysis completed at #{report[:summary][:analysis_timestamp]}"
    puts "="*80
  end
end

# Load test output and analyze
if __FILE__ == $0
  test_output = <<~TEST_OUTPUT
=== RUNNING ALL CATEGORIES COMBINED ===

📊 Coverage configured for: Combined Coverage Report
   Report will be saved to: test/coverage/all/

Loading infrastructure tests...
🧪 Loading 19 test files from infrastructure:
   - test_ast_nodes
   - test_complex_logic_queries
   - test_error_handling_coverage
   - test_facts_database
   - test_function_lexer
   - test_function_parser
   - test_goal_resolution_engine
   - test_lexer
   - test_lexer_branch_coverage
   - test_lexer_comprehensive
   - test_lexer_error_recovery
   - test_lexer_error_scenarios
   - test_parser
   - test_parser_branch_coverage
   - test_parser_edge_cases
   - test_reasoning_coordinator
   - test_type_constraint_parser
   - test_type_constraint_system
   - test_unification_engine
✅ All infrastructure tests loaded successfully!

Loading ruby_implementation tests...
🧪 Loading 15 test files from ruby_implementation:
   - test_advanced_goal_strategies
   - test_evaluator_edge_cases
   - test_evaluator_stress
   - test_extended_string_methods
   - test_function_evaluator
   - test_goal_system
   - test_object_model
   - test_object_model_comprehensive
   - test_object_model_edge_cases
   - test_object_model_stress
   - test_reasoning_evaluator_integration
   - test_string_literals
   - test_string_operations
   - test_type_constraints
   - test_type_constraints_clean
✅ All ruby_implementation tests loaded successfully!

Loading patlang_language tests...
1063 runs, 3839 assertions, 154 failures, 419 errors, 5 skips

You have skipped tests. Run with --verbose for details.
Coverage report generated for Unit Tests to E:/patlang/test/coverage/all.
Line Coverage: 39.97% (3739 / 9354)
Branch Coverage: 28.22% (801 / 2838)
Branch coverage (28.22%) is below the expected minimum coverage (50.00%).
  TEST_OUTPUT

  analyzer = TestErrorAnalyzer.new
  analyzer.analyze_test_output(test_output)
  analyzer.print_summary
  analyzer.save_report
end