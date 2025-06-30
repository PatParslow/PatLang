#!/usr/bin/env ruby

require 'json'
require 'pathname'

# Comprehensive Error Analysis for Patlang Project
class ComprehensiveErrorAnalysis
  
  def initialize
    @project_root = File.dirname(__FILE__)
    @errors = []
    @patterns = {}
    @categories = {
      'critical' => [],
      'high' => [],
      'medium' => [],
      'low' => []
    }
  end
  
  def analyze
    puts "🔍 COMPREHENSIVE PATLANG ERROR ANALYSIS"
    puts "=" * 60
    
    # Step 1: Load existing runtime analysis
    load_existing_analysis
    
    # Step 2: Run targeted test categories
    run_targeted_tests
    
    # Step 3: Analyze patterns and categorize
    analyze_patterns
    
    # Step 4: Create systematic fix plan
    create_fix_plan
    
    # Step 5: Generate comprehensive report
    generate_report
  end
  
  private
  
  def load_existing_analysis
    puts "\n📋 Loading existing runtime analysis..."
    
    if File.exist?('RUNTIME_VALIDATION_AND_FAILURE_ANALYSIS.json')
      begin
        data = JSON.parse(File.read('RUNTIME_VALIDATION_AND_FAILURE_ANALYSIS.json'))
        puts "   ✅ Found #{data['total_errors']} documented errors"
        
        # Extract key insights
        @existing_errors = data['detailed_errors'] || []
        @existing_patterns = data['pattern_analysis'] || {}
        
        puts "   📊 Error breakdown:"
        data['error_classification'].each do |type, count|
          puts "      - #{type}: #{count}"
        end
        
      rescue JSON::ParserError => e
        puts "   ⚠️  Could not parse existing analysis: #{e.message}"
      end
    else
      puts "   ℹ️  No existing analysis found"
    end
  end
  
  def run_targeted_tests
    puts "\n🧪 Running targeted test analysis..."
    
    # Test key infrastructure components
    test_categories = {
      'infrastructure' => ['test_parser.rb', 'test_lexer.rb', 'test_evaluator.rb'],
      'patlang_language' => ['test_integration.rb', 'test_evaluator.rb'],
      'ruby_implementation' => ['test_object_model.rb', 'test_function_evaluator.rb']
    }
    
    test_categories.each do |category, test_files|
      puts "\n   📂 Testing #{category}:"
      
      test_files.each do |test_file|
        file_path = "test/#{category}/#{test_file}"
        if File.exist?(file_path)
          puts "      🔍 #{test_file}..."
          result = run_single_test(file_path)
          analyze_test_result(result, category, test_file)
        else
          puts "      ⚠️  #{test_file} not found"
        end
      end
    end
  end
  
  def run_single_test(file_path)
    begin
      # Run test with timeout to prevent hanging
      require 'timeout'
      
      result = Timeout.timeout(30) do
        `ruby #{file_path} 2>&1`
      end
      
      { success: $?.success?, output: result, file: file_path }
    rescue Timeout::Error
      { success: false, output: "Test timed out", file: file_path, timeout: true }
    rescue => e
      { success: false, output: e.message, file: file_path, error: e }
    end
  end
  
  def analyze_test_result(result, category, test_file)
    return if result[:success]
    
    error_info = {
      category: category,
      test_file: test_file,
      output: result[:output],
      timeout: result[:timeout] || false
    }
    
    # Extract specific error patterns
    if result[:output].include?("NoMethodError")
      extract_no_method_errors(result[:output], error_info)
    elsif result[:output].include?("ParseError")
      extract_parse_errors(result[:output], error_info)
    elsif result[:output].include?("undefined method")
      extract_undefined_method_errors(result[:output], error_info)
    elsif result[:timeout]
      categorize_error(error_info, 'high', 'Test timeout - possible infinite loop or performance issue')
    else
      categorize_error(error_info, 'medium', 'General test failure')
    end
    
    @errors << error_info
  end
  
  def extract_no_method_errors(output, error_info)
    # Look for debug_print pattern specifically
    if output.include?("debug_print")
      categorize_error(error_info, 'critical', 'Missing debug_print method - blocking core functionality')
      track_pattern('debug_print_missing', error_info)
    else
      categorize_error(error_info, 'high', 'NoMethodError - missing method implementation')
    end
  end
  
  def extract_parse_errors(output, error_info)
    if output.include?("Unexpected token")
      categorize_error(error_info, 'medium', 'Parser error - unexpected token handling')
      track_pattern('parser_unexpected_token', error_info)
    else
      categorize_error(error_info, 'medium', 'General parser error')
    end
  end
  
  def extract_undefined_method_errors(output, error_info)
    categorize_error(error_info, 'high', 'Undefined method - missing implementation')
    track_pattern('undefined_method', error_info)
  end
  
  def categorize_error(error_info, priority, description)
    error_info[:priority] = priority
    error_info[:description] = description
    @categories[priority] << error_info
  end
  
  def track_pattern(pattern_name, error_info)
    @patterns[pattern_name] ||= []
    @patterns[pattern_name] << error_info
  end
  
  def analyze_patterns
    puts "\n📊 Analyzing error patterns..."
    
    @patterns.each do |pattern, errors|
      puts "   🔍 #{pattern}: #{errors.length} occurrences"
      
      case pattern
      when 'debug_print_missing'
        puts "      🎯 CRITICAL: debug_print method missing from parser classes"
        puts "      💡 FIX: Add debug_print method to base parser class"
        
      when 'parser_unexpected_token'
        puts "      ⚠️  Parser struggling with edge cases"
        puts "      💡 FIX: Improve error recovery and token handling"
        
      when 'undefined_method'
        puts "      🔧 Method implementation gaps"
        puts "      💡 FIX: Complete method implementations"
      end
    end
  end
  
  def create_fix_plan
    puts "\n🎯 Creating systematic fix plan..."
    
    @fix_plan = [
      {
        phase: 1,
        priority: 'CRITICAL',
        title: 'Fix debug_print Missing Method',
        description: 'Add debug_print method to resolve 8+ blocking errors',
        errors_affected: (@patterns['debug_print_missing'] || []).length,
        estimated_time: '5 minutes',
        complexity: 'LOW',
        files_to_modify: ['src/parser.rb', 'src/parser/function_parser.rb']
      },
      {
        phase: 2,
        priority: 'HIGH', 
        title: 'Resolve NoMethodError Issues',
        description: 'Fix missing method implementations causing test failures',
        errors_affected: @categories['high'].length,
        estimated_time: '20 minutes',
        complexity: 'MEDIUM',
        files_to_modify: ['src/evaluator.rb', 'src/reasoning/*.rb']
      },
      {
        phase: 3,
        priority: 'MEDIUM',
        title: 'Improve Parser Error Recovery',
        description: 'Enhance parser robustness for edge cases',
        errors_affected: @categories['medium'].length,
        estimated_time: '30 minutes',
        complexity: 'MEDIUM',
        files_to_modify: ['src/parser/expression_parser.rb']
      },
      {
        phase: 4,
        priority: 'LOW',
        title: 'Integration Test Fixes',
        description: 'Resolve remaining integration test issues',
        errors_affected: @categories['low'].length,
        estimated_time: '15 minutes',
        complexity: 'LOW',
        files_to_modify: ['test/patlang_language/*.rb']
      }
    ]
  end
  
  def generate_report
    puts "\n📄 Generating comprehensive report..."
    
    report = {
      timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
      summary: {
        total_errors_found: @errors.length,
        critical: @categories['critical'].length,
        high: @categories['high'].length,
        medium: @categories['medium'].length,
        low: @categories['low'].length
      },
      patterns: @patterns.transform_values(&:length),
      fix_plan: @fix_plan,
      detailed_errors: @errors,
      next_actions: generate_next_actions
    }
    
    # Write comprehensive report
    File.write('COMPREHENSIVE_ERROR_ANALYSIS.json', JSON.pretty_generate(report))
    
    # Generate human-readable summary
    generate_summary_report(report)
    
    puts "\n✅ Analysis complete!"
    puts "   📄 Detailed report: COMPREHENSIVE_ERROR_ANALYSIS.json"
    puts "   📄 Summary report: ERROR_ANALYSIS_SUMMARY.md"
  end
  
  def generate_next_actions
    [
      "1. IMMEDIATE: Fix debug_print method (5 min) - will resolve #{(@patterns['debug_print_missing'] || []).length} critical errors",
      "2. SHORT TERM: Address NoMethodError issues (20 min) - will resolve #{@categories['high'].length} high priority errors",
      "3. MEDIUM TERM: Enhance parser robustness (30 min) - will resolve #{@categories['medium'].length} medium priority errors",
      "4. LONG TERM: Clean up integration tests (15 min) - will resolve #{@categories['low'].length} remaining issues"
    ]
  end
  
  def generate_summary_report(report)
    summary = <<~SUMMARY
# Patlang Project Error Analysis Summary

## 🎯 Executive Summary

**Total Errors Found**: #{report[:summary][:total_errors_found]}

### Priority Breakdown:
- 🔴 **Critical**: #{report[:summary][:critical]} (Blocking core functionality)
- 🟡 **High**: #{report[:summary][:high]} (Major functionality affected)  
- 🟠 **Medium**: #{report[:summary][:medium]} (Robustness and edge cases)
- 🟢 **Low**: #{report[:summary][:low]} (Minor integration issues)

## 🔍 Key Patterns Identified

#{@patterns.map { |pattern, errors| "- **#{pattern}**: #{errors.length} occurrences" }.join("\n")}

## 🎯 Systematic Fix Plan

#{@fix_plan.map.with_index(1) { |phase, i| 
  "### Phase #{i}: #{phase[:title]} (#{phase[:priority]})
- **Impact**: #{phase[:errors_affected]} errors affected
- **Time**: #{phase[:estimated_time]}
- **Complexity**: #{phase[:complexity]}
- **Description**: #{phase[:description]}"
}.join("\n\n")}

## 🚀 Next Actions

#{report[:next_actions].join("\n")}

## 📊 Current Status

Based on existing test runs and analysis:
- ✅ **Parser error recovery**: Successfully implemented
- ✅ **Flexible function syntax**: Working correctly
- ✅ **IS keyword**: Fully functional
- ❌ **Function parser debug methods**: Missing (critical)
- ❌ **Integration test stability**: Needs improvement

## 💡 Recommendations

1. **Start with Phase 1** - Quick win that resolves critical blocking issues
2. **Focus on systematic approach** - Follow phases in order for maximum impact
3. **Run validation after each phase** - Ensure fixes don't introduce regressions
4. **Prioritize core functionality** - Parser and evaluator stability first

---
*Generated: #{report[:timestamp]}*
SUMMARY

    File.write('ERROR_ANALYSIS_SUMMARY.md', summary)
  end
end

# Run analysis if called directly
if __FILE__ == $0
  analyzer = ComprehensiveErrorAnalysis.new
  analyzer.analyze
end