#!/usr/bin/env ruby
# frozen_string_literal: true

# Critical Test Failures Diagnostic Tool
# This script systematically diagnoses the top 5 critical issues identified

require 'json'

class CriticalIssuesDiagnostic
  def initialize
    @results = {
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
      issues: {}
    }
  end

  def run_all_diagnostics
    puts "🔍 CRITICAL TEST FAILURES DIAGNOSTIC"
    puts "=" * 50
    
    diagnose_typeconstraint_loading
    diagnose_unknown_errors
    diagnose_timeout_issues
    diagnose_parser_edge_cases
    diagnose_cross_paradigm_failures
    
    generate_report
  end

  # Issue 1: TypeConstraintSystem Loading Issues
  def diagnose_typeconstraint_loading
    puts "\n🚨 ISSUE 1: TypeConstraintSystem Loading"
    puts "-" * 40
    
    issue_data = {
      description: "TypeConstraintSystem not loading properly",
      status: "investigating",
      findings: []
    }
    
    # Check if TypeConstraintSystem file exists
    type_constraint_system_path = "src/reasoning/type_constraint_system.rb"
    if File.exist?(type_constraint_system_path)
      issue_data[:findings] << "✅ TypeConstraintSystem file exists at #{type_constraint_system_path}"
      puts "✅ TypeConstraintSystem file exists"
    else
      issue_data[:findings] << "❌ TypeConstraintSystem file missing at #{type_constraint_system_path}"
      puts "❌ TypeConstraintSystem file missing"
    end
    
    # Check test require path
    test_file = "test/ruby_implementation/test_type_constraints_clean.rb"
    if File.exist?(test_file)
      content = File.read(test_file)
      if content.include?("require_relative '../../src/reasoning/type_constraint'")
        issue_data[:findings] << "❌ Test requires type_constraint.rb but needs type_constraint_system.rb"
        puts "❌ Incorrect require path in test - should include type_constraint_system.rb"
        
        # Check if TypeConstraintSystem is defined in the required file
        type_constraint_file = "src/reasoning/type_constraint.rb"
        if File.exist?(type_constraint_file)
          tc_content = File.read(type_constraint_file)
          if tc_content.include?("TypeConstraintSystem")
            issue_data[:findings] << "⚠️  TypeConstraintSystem found in type_constraint.rb"
          else
            issue_data[:findings] << "❌ TypeConstraintSystem NOT found in type_constraint.rb"
            puts "❌ TypeConstraintSystem not defined in required file"
          end
        end
      end
    end
    
    # Test basic loading
    begin
      require_relative '../src/reasoning/type_constraint_system'
      if defined?(TypeConstraintSystem)
        issue_data[:findings] << "✅ TypeConstraintSystem can be loaded successfully"
        issue_data[:status] = "fixable"
        puts "✅ TypeConstraintSystem loads successfully when properly required"
      end
    rescue LoadError => e
      issue_data[:findings] << "❌ LoadError: #{e.message}"
      issue_data[:status] = "broken"
      puts "❌ LoadError: #{e.message}"
    rescue NameError => e
      issue_data[:findings] << "❌ NameError: #{e.message}"
      issue_data[:status] = "broken"
      puts "❌ NameError: #{e.message}"
    end
    
    @results[:issues][:typeconstraint_loading] = issue_data
  end

  # Issue 2: Unknown Error Epidemic 
  def diagnose_unknown_errors
    puts "\n🚨 ISSUE 2: Unknown Error Epidemic"
    puts "-" * 40
    
    issue_data = {
      description: "16 files with unknown_error status",
      status: "investigating", 
      findings: [],
      affected_files: []
    }
    
    # Read the test report to get unknown error files
    report_file = "test/COMPREHENSIVE_TEST_SUITE_REPORT.json"
    if File.exist?(report_file)
      begin
        report = JSON.parse(File.read(report_file))
        unknown_errors = report["errors"].select { |error| error["error_type"] == "unknown_error" }
        
        issue_data[:affected_files] = unknown_errors.map { |e| e["relative_path"] }
        issue_data[:findings] << "📊 Found #{unknown_errors.length} files with unknown_error"
        puts "📊 Found #{unknown_errors.length} files with unknown_error"
        
        # Analyze patterns
        categories = unknown_errors.group_by { |e| e["category"] }
        categories.each do |category, files|
          issue_data[:findings] << "📂 #{category}: #{files.length} files"
          puts "📂 #{category}: #{files.length} files"
        end
        
        # Check if these are require/loading issues
        sample_file = unknown_errors.first
        if sample_file
          puts "🔍 Analyzing sample file: #{sample_file['relative_path']}"
          
          # Check if exit_status is null (indication of silent failure)
          if sample_file["exit_status"].nil?
            issue_data[:findings] << "⚠️  Exit status is null - suggests silent failures"
            puts "⚠️  Exit status is null - suggests silent failures"
          end
          
          # Check if there's output but no error_output
          if sample_file["output"] && sample_file["output"].length > 0 && 
             (sample_file["error_output"].nil? || sample_file["error_output"].empty?)
            issue_data[:findings] << "⚠️  Tests start but don't complete - possible hanging"
            puts "⚠️  Tests start but don't complete - possible hanging"
          end
        end
        
      rescue JSON::ParserError => e
        issue_data[:findings] << "❌ Could not parse test report: #{e.message}"
        puts "❌ Could not parse test report: #{e.message}"
      end
    else
      issue_data[:findings] << "❌ Test report file not found"
      puts "❌ Test report file not found"
    end
    
    @results[:issues][:unknown_errors] = issue_data
  end

  # Issue 3: Timeout in Reasoning Integration
  def diagnose_timeout_issues
    puts "\n🚨 ISSUE 3: Timeout Issues"  
    puts "-" * 40
    
    issue_data = {
      description: "Timeouts in reasoning integration and parser edge cases",
      status: "investigating",
      findings: []
    }
    
    timeout_files = [
      "test/patlang_language/test_reasoning_integration.rb",
      "test/infrastructure/test_parser_edge_cases.rb"
    ]
    
    timeout_files.each do |file|
      if File.exist?(file)
        issue_data[:findings] << "✅ Timeout file exists: #{file}"
        puts "✅ Found timeout file: #{file}"
        
        # Look for emergency timeout references
        content = File.read(file)
        if content.include?("EmergencyTimeout")
          issue_data[:findings] << "⚠️  File uses EmergencyTimeout protection"
          puts "⚠️  #{file} uses EmergencyTimeout protection"
        end
        
        if content.include?("postcondition")
          issue_data[:findings] << "🔍 File tests postcondition parsing"
          puts "🔍 #{file} tests postcondition parsing"
        end
      else
        issue_data[:findings] << "❌ Timeout file missing: #{file}"
        puts "❌ Missing timeout file: #{file}"
      end
    end
    
    # Check if emergency timeout system exists
    emergency_timeout_file = "src/emergency_timeout.rb"
    if File.exist?(emergency_timeout_file)
      issue_data[:findings] << "✅ EmergencyTimeout system exists"
      puts "✅ EmergencyTimeout system exists"
    else
      issue_data[:findings] << "❌ EmergencyTimeout system missing"
      puts "❌ EmergencyTimeout system missing"
    end
    
    @results[:issues][:timeout_issues] = issue_data
  end

  # Issue 4: Parser Edge Cases
  def diagnose_parser_edge_cases
    puts "\n🚨 ISSUE 4: Parser Edge Cases"
    puts "-" * 40
    
    issue_data = {
      description: "Parser edge cases causing failures and timeouts",
      status: "investigating", 
      findings: []
    }
    
    parser_files = [
      "src/parser.rb",
      "test/infrastructure/test_parser_edge_cases.rb",
      "test/infrastructure/test_lexer_error_scenarios.rb"
    ]
    
    parser_files.each do |file|
      if File.exist?(file)
        issue_data[:findings] << "✅ Parser file exists: #{file}"
        puts "✅ Found parser file: #{file}"
      else
        issue_data[:findings] << "❌ Parser file missing: #{file}"
        puts "❌ Missing parser file: #{file}"
      end
    end
    
    @results[:issues][:parser_edge_cases] = issue_data
  end

  # Issue 5: Cross-Paradigm Integration
  def diagnose_cross_paradigm_failures
    puts "\n🚨 ISSUE 5: Cross-Paradigm Integration"
    puts "-" * 40
    
    issue_data = {
      description: "Cross-paradigm coordination and event system failures",
      status: "investigating",
      findings: []
    }
    
    cross_paradigm_files = [
      "test/patlang_language/test_cross_paradigm_coordination.rb",
      "test/patlang_language/test_form_validation.rb",
      "test/patlang_language/test_goal_declaration_syntax.rb"
    ]
    
    cross_paradigm_files.each do |file|
      if File.exist?(file)
        issue_data[:findings] << "✅ Cross-paradigm file exists: #{file}"
        puts "✅ Found cross-paradigm file: #{file}"
      else
        issue_data[:findings] << "❌ Cross-paradigm file missing: #{file}"
        puts "❌ Missing cross-paradigm file: #{file}"
      end
    end
    
    @results[:issues][:cross_paradigm_failures] = issue_data
  end

  def generate_report
    puts "\n📋 DIAGNOSTIC REPORT SUMMARY"
    puts "=" * 50
    
    @results[:issues].each do |issue_name, issue_data|
      puts "\n#{issue_name.to_s.upcase.gsub('_', ' ')}: #{issue_data[:status]}"
      issue_data[:findings].each { |finding| puts "  #{finding}" }
    end
    
    # Write detailed JSON report
    File.write("test/CRITICAL_ISSUES_DIAGNOSTIC.json", JSON.pretty_generate(@results))
    puts "\n💾 Detailed report saved to: test/CRITICAL_ISSUES_DIAGNOSTIC.json"
    
    puts "\n🎯 RECOMMENDED NEXT STEPS:"
    puts "1. Fix TypeConstraintSystem require path in test_type_constraints_clean.rb"
    puts "2. Add comprehensive logging to unknown error tests"
    puts "3. Add timeout debugging to reasoning integration"
    puts "4. Investigate parser edge case infinite loops"
    puts "5. Debug event system coordination"
  end
end

# Run the diagnostic if called directly
if __FILE__ == $0
  diagnostic = CriticalIssuesDiagnostic.new
  diagnostic.run_all_diagnostics
end