#!/usr/bin/env ruby

# CI-Compatible Coverage Analysis
# This version works without external dependencies like simplecov

require 'json'
require 'fileutils'

class CICompatibleCoverageAnalysis
  def initialize
    @coverage_data = {
      source_files: [],
      test_files: [],
      coverage_metrics: {},
      analysis: {}
    }
  end

  def run_analysis
    puts "📊 CI-COMPATIBLE COVERAGE ANALYSIS"
    puts "=" * 50
    
    analyze_source_structure
    analyze_test_structure
    calculate_coverage_metrics
    generate_ci_coverage_report
    
    display_results
  end

  private

  def analyze_source_structure
    puts "\n🔍 Analyzing source code structure..."
    
    source_patterns = [
      'src/**/*.rb',
      'lib/**/*.rb'
    ]
    
    source_patterns.each do |pattern|
      Dir.glob(pattern).each do |file|
        @coverage_data[:source_files] << {
          file: file,
          lines: count_lines(file),
          methods: count_methods(file),
          classes: count_classes(file)
        }
      end
    end
    
    puts "  📁 Found #{@coverage_data[:source_files].length} source files"
  end

  def analyze_test_structure
    puts "\n🧪 Analyzing test structure..."
    
    test_patterns = [
      'test/**/*test*.rb',
      'spec/**/*spec*.rb'
    ]
    
    test_patterns.each do |pattern|
      Dir.glob(pattern).each do |file|
        @coverage_data[:test_files] << {
          file: file,
          lines: count_lines(file),
          test_methods: count_test_methods(file)
        }
      end
    end
    
    puts "  🧪 Found #{@coverage_data[:test_files].length} test files"
  end

  def count_lines(file)
    File.readlines(file).reject { |line| line.strip.empty? || line.strip.start_with?('#') }.length
  rescue
    0
  end

  def count_methods(file)
    content = File.read(file)
    content.scan(/def\s+\w+/).length
  rescue
    0
  end

  def count_classes(file)
    content = File.read(file)
    content.scan(/class\s+\w+/).length
  rescue
    0
  end

  def count_test_methods(file)
    content = File.read(file)
    content.scan(/def\s+test_\w+/).length
  rescue
    0
  end

  def calculate_coverage_metrics
    puts "\n📊 Calculating coverage metrics..."
    
    total_source_lines = @coverage_data[:source_files].sum { |f| f[:lines] }
    total_source_methods = @coverage_data[:source_files].sum { |f| f[:methods] }
    total_source_classes = @coverage_data[:source_files].sum { |f| f[:classes] }
    
    total_test_lines = @coverage_data[:test_files].sum { |f| f[:lines] }
    total_test_methods = @coverage_data[:test_files].sum { |f| f[:test_methods] }
    
    # Calculate basic coverage ratios
    test_to_source_ratio = total_source_lines > 0 ? (total_test_lines.to_f / total_source_lines * 100).round(2) : 0
    test_method_coverage = total_source_methods > 0 ? (total_test_methods.to_f / total_source_methods * 100).round(2) : 0
    
    @coverage_data[:coverage_metrics] = {
      source_files_count: @coverage_data[:source_files].length,
      test_files_count: @coverage_data[:test_files].length,
      total_source_lines: total_source_lines,
      total_test_lines: total_test_lines,
      total_source_methods: total_source_methods,
      total_test_methods: total_test_methods,
      total_source_classes: total_source_classes,
      test_to_source_ratio: test_to_source_ratio,
      test_method_coverage: test_method_coverage,
      files_with_tests: count_files_with_tests,
      files_without_tests: count_files_without_tests
    }
  end

  def count_files_with_tests
    @coverage_data[:source_files].count do |src_file|
      src_name = File.basename(src_file[:file], '.rb')
      @coverage_data[:test_files].any? do |test_file|
        test_file[:file].include?(src_name) || test_file[:file].include?('test_' + src_name)
      end
    end
  end

  def count_files_without_tests
    @coverage_data[:source_files].length - count_files_with_tests
  end

  def generate_ci_coverage_report
    puts "\n💾 Generating CI coverage report..."
    
    report = {
      timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
      coverage_analysis: @coverage_data[:coverage_metrics],
      source_files: @coverage_data[:source_files],
      test_files: @coverage_data[:test_files],
      summary: {
        status: determine_coverage_status,
        recommendations: generate_recommendations
      }
    }
    
    File.write('CI_COVERAGE_ANALYSIS_REPORT.json', JSON.pretty_generate(report))
    puts "  📄 Report saved: CI_COVERAGE_ANALYSIS_REPORT.json"
  end

  def determine_coverage_status
    metrics = @coverage_data[:coverage_metrics]
    
    if metrics[:test_to_source_ratio] >= 80 && metrics[:test_method_coverage] >= 70
      'EXCELLENT'
    elsif metrics[:test_to_source_ratio] >= 60 && metrics[:test_method_coverage] >= 50
      'GOOD'
    elsif metrics[:test_to_source_ratio] >= 40 && metrics[:test_method_coverage] >= 30
      'MODERATE'
    else
      'NEEDS_IMPROVEMENT'
    end
  end

  def generate_recommendations
    metrics = @coverage_data[:coverage_metrics]
    recommendations = []
    
    if metrics[:files_without_tests] > 0
      recommendations << "Add tests for #{metrics[:files_without_tests]} source files without test coverage"
    end
    
    if metrics[:test_method_coverage] < 50
      recommendations << "Increase test method coverage (currently #{metrics[:test_method_coverage]}%)"
    end
    
    if metrics[:test_to_source_ratio] < 60
      recommendations << "Increase test-to-source ratio (currently #{metrics[:test_to_source_ratio]}%)"
    end
    
    if recommendations.empty?
      recommendations << "Coverage metrics are healthy - continue maintaining quality"
    end
    
    recommendations
  end

  def display_results
    puts "\n" + "=" * 50
    puts "📊 CI-COMPATIBLE COVERAGE ANALYSIS RESULTS"
    puts "=" * 50
    
    metrics = @coverage_data[:coverage_metrics]
    
    puts "\n📁 SOURCE CODE ANALYSIS:"
    puts "  Source files: #{metrics[:source_files_count]}"
    puts "  Source lines: #{metrics[:total_source_lines]}"
    puts "  Source methods: #{metrics[:total_source_methods]}"
    puts "  Source classes: #{metrics[:total_source_classes]}"
    
    puts "\n🧪 TEST CODE ANALYSIS:"
    puts "  Test files: #{metrics[:test_files_count]}"
    puts "  Test lines: #{metrics[:total_test_lines]}"
    puts "  Test methods: #{metrics[:total_test_methods]}"
    
    puts "\n📊 COVERAGE METRICS:"
    puts "  Test-to-source ratio: #{metrics[:test_to_source_ratio]}%"
    puts "  Test method coverage: #{metrics[:test_method_coverage]}%"
    puts "  Files with tests: #{metrics[:files_with_tests]}"
    puts "  Files without tests: #{metrics[:files_without_tests]}"
    
    puts "\n🎯 COVERAGE STATUS: #{determine_coverage_status}"
    
    puts "\n💡 RECOMMENDATIONS:"
    generate_recommendations.each_with_index do |rec, i|
      puts "  #{i+1}. #{rec}"
    end
    
    puts "\n✅ CI-COMPATIBLE COVERAGE ANALYSIS COMPLETED"
    puts "   Analysis complete - no external dependencies required!"
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = CICompatibleCoverageAnalysis.new
  analyzer.run_analysis
end