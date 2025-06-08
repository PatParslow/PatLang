#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'time'

class ComprehensiveErrorDetectionAnalysis
  def initialize
    @test_dir = 'test'
    @results = {
      critical_failures: [],
      error_categories: {},
      test_execution_summary: {},
      coverage_gaps: [],
      prioritized_fixes: [],
      quick_wins: []
    }
  end

  def run_analysis
    puts "🔍 COMPREHENSIVE ERROR DETECTION AND ANALYSIS"
    puts "=" * 60
    
    # Step 1: Run direct test execution to get detailed error information
    run_failing_tests_analysis
    
    # Step 2: Categorize errors by type
    categorize_errors
    
    # Step 3: Identify critical path failures
    analyze_critical_paths
    
    # Step 4: Find coverage gaps in error handling
    analyze_coverage_gaps
    
    # Step 5: Generate prioritized roadmap
    generate_fix_roadmap
    
    # Step 6: Save comprehensive report
    save_analysis_report
    
    display_summary
  end

  private

  def run_failing_tests_analysis
    puts "🚀 Running detailed analysis of known failing tests..."
    
    failing_tests = [
      'patlang_language/test_integration.rb',
      'patlang_language/test_evaluator.rb', 
      'infrastructure/test_complex_logic_queries.rb'
    ]
    
    failing_tests.each do |test_file|
      puts "\n📋 Analyzing: #{test_file}"
      analyze_individual_test_failure(test_file)
    end
  end

  def analyze_individual_test_failure(test_file)
    test_path = File.join(@test_dir, test_file)
    
    unless File.exist?(test_path)
      @results[:critical_failures] << {
        test: test_file,
        error_type: 'FILE_NOT_FOUND',
        severity: 'CRITICAL',
        description: "Test file does not exist at expected path"
      }
      return
    end

    # Run the test and capture output
    begin
      output = `cd #{@test_dir} && ruby #{test_file} 2>&1`
      exit_code = $?.exitstatus
      
      if exit_code != 0
        error_info = parse_test_error(output, test_file)
        @results[:critical_failures] << error_info
      end
    rescue => e
      @results[:critical_failures] << {
        test: test_file,
        error_type: 'EXECUTION_ERROR',
        severity: 'CRITICAL',
        description: e.message,
        details: e.backtrace.first(5)
      }
    end
  end

  def parse_test_error(output, test_file)
    error_info = {
      test: test_file,
      full_output: output,
      severity: 'HIGH'
    }

    # Detect common error patterns
    case output
    when /LoadError.*cannot load such file/
      error_info[:error_type] = 'LOAD_ERROR'
      error_info[:description] = 'Missing dependency or incorrect require path'
      error_info[:severity] = 'CRITICAL'
    when /NoMethodError/
      error_info[:error_type] = 'NO_METHOD_ERROR'
      error_info[:description] = 'Method not defined or incorrect method call'
      error_info[:severity] = 'HIGH'
    when /SyntaxError/
      error_info[:error_type] = 'SYNTAX_ERROR'
      error_info[:description] = 'Invalid Ruby syntax'
      error_info[:severity] = 'CRITICAL'
    when /NameError.*uninitialized constant/
      error_info[:error_type] = 'NAME_ERROR'
      error_info[:description] = 'Undefined constant or class'
      error_info[:severity] = 'CRITICAL'
    when /NotImplementedError/
      error_info[:error_type] = 'NOT_IMPLEMENTED'
      error_info[:description] = 'Method stub not implemented'
      error_info[:severity] = 'MEDIUM'
    when /ArgumentError/
      error_info[:error_type] = 'ARGUMENT_ERROR'
      error_info[:description] = 'Incorrect method arguments'
      error_info[:severity] = 'MEDIUM'
    else
      error_info[:error_type] = 'UNKNOWN'
      error_info[:description] = 'Unclassified error requiring investigation'
      error_info[:severity] = 'HIGH'
    end

    error_info
  end

  def categorize_errors
    puts "\n📊 Categorizing errors by type..."
    
    @results[:critical_failures].each do |failure|
      error_type = failure[:error_type]
      @results[:error_categories][error_type] ||= []
      @results[:error_categories][error_type] << failure
    end
    
    @results[:error_categories].each do |type, failures|
      puts "  #{type}: #{failures.length} occurrences"
    end
  end

  def analyze_critical_paths
    puts "\n🎯 Analyzing critical path failures..."
    
    # Identify tests that are fundamental to unified reasoning
    critical_reasoning_tests = [
      'test_evaluator.rb',
      'test_integration.rb',
      'test_reasoning_coordinator.rb',
      'test_unification_engine.rb',
      'test_goal_resolution_engine.rb'
    ]
    
    critical_failures = @results[:critical_failures].select do |failure|
      critical_reasoning_tests.any? { |critical| failure[:test].include?(critical) }
    end
    
    @results[:critical_path_failures] = critical_failures
    puts "  Found #{critical_failures.length} critical path failures"
  end

  def analyze_coverage_gaps
    puts "\n📈 Analyzing test coverage gaps..."
    
    # Check for missing test coverage in key areas
    src_files = Dir.glob('src/**/*.rb')
    test_files = Dir.glob('test/**/*.rb')
    
    coverage_gaps = []
    
    src_files.each do |src_file|
      src_name = File.basename(src_file, '.rb')
      has_test = test_files.any? { |test| test.include?(src_name) }
      
      unless has_test
        coverage_gaps << {
          file: src_file,
          gap_type: 'NO_TEST_FILE',
          priority: 'MEDIUM',
          description: "No corresponding test file found"
        }
      end
    end
    
    @results[:coverage_gaps] = coverage_gaps
    puts "  Found #{coverage_gaps.length} coverage gaps"
  end

  def generate_fix_roadmap
    puts "\n🗺️  Generating prioritized fix roadmap..."
    
    # Group fixes by priority and impact
    critical_fixes = @results[:critical_failures].select { |f| f[:severity] == 'CRITICAL' }
    high_fixes = @results[:critical_failures].select { |f| f[:severity] == 'HIGH' }
    medium_fixes = @results[:critical_failures].select { |f| f[:severity] == 'MEDIUM' }
    
    # Identify quick wins (easy fixes with high impact)
    quick_wins = []
    
    @results[:critical_failures].each do |failure|
      case failure[:error_type]
      when 'LOAD_ERROR', 'NAME_ERROR'
        quick_wins << {
          test: failure[:test],
          fix_type: 'DEPENDENCY_FIX',
          effort: 'LOW',
          impact: 'HIGH',
          description: 'Fix require statements or class definitions'
        }
      when 'NOT_IMPLEMENTED'
        quick_wins << {
          test: failure[:test],
          fix_type: 'STUB_IMPLEMENTATION',
          effort: 'MEDIUM',
          impact: 'MEDIUM',
          description: 'Implement method stubs with basic functionality'
        }
      end
    end
    
    @results[:prioritized_fixes] = {
      critical: critical_fixes,
      high: high_fixes,
      medium: medium_fixes
    }
    
    @results[:quick_wins] = quick_wins.uniq { |qw| qw[:test] }
    
    puts "  Critical fixes: #{critical_fixes.length}"
    puts "  High priority fixes: #{high_fixes.length}"
    puts "  Medium priority fixes: #{medium_fixes.length}"
    puts "  Quick wins identified: #{@results[:quick_wins].length}"
  end

  def save_analysis_report
    puts "\n💾 Saving comprehensive analysis report..."
    
    report = {
      analysis_timestamp: Time.now.iso8601,
      summary: {
        total_failures: @results[:critical_failures].length,
        error_categories: @results[:error_categories].transform_values(&:length),
        critical_path_failures: @results[:critical_path_failures]&.length || 0,
        coverage_gaps: @results[:coverage_gaps].length,
        quick_wins_available: @results[:quick_wins].length
      },
      detailed_results: @results
    }
    
    File.write('COMPREHENSIVE_ERROR_DETECTION_REPORT.json', JSON.pretty_generate(report))
    puts "  Report saved to: COMPREHENSIVE_ERROR_DETECTION_REPORT.json"
  end

  def display_summary
    puts "\n" + "=" * 60
    puts "📋 COMPREHENSIVE ERROR ANALYSIS SUMMARY"
    puts "=" * 60
    
    puts "\n🔥 CRITICAL ISSUES:"
    critical = @results[:prioritized_fixes][:critical] || []
    critical.each_with_index do |issue, i|
      puts "  #{i+1}. #{issue[:test]} - #{issue[:error_type]}"
      puts "     #{issue[:description]}"
    end
    
    puts "\n⚡ QUICK WINS AVAILABLE:"
    @results[:quick_wins].each_with_index do |win, i|
      puts "  #{i+1}. #{win[:test]} - #{win[:fix_type]} (#{win[:effort]} effort, #{win[:impact]} impact)"
    end
    
    puts "\n📊 ERROR DISTRIBUTION:"
    @results[:error_categories].each do |type, failures|
      puts "  #{type}: #{failures.length} tests"
    end
    
    puts "\n🎯 NEXT STEPS:"
    puts "  1. Fix critical LoadError and NameError issues first"
    puts "  2. Implement NotImplementedError method stubs"
    puts "  3. Address syntax errors in core reasoning components"
    puts "  4. Expand test coverage for error handling paths"
    puts "  5. Run targeted tests after each fix to validate progress"
    
    puts "\n✅ Analysis completed. Use intelligent test scheduling for efficient fixing workflow."
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = ComprehensiveErrorDetectionAnalysis.new
  analyzer.run_analysis
end