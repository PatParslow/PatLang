#!/usr/bin/env ruby

# Critical Infinite Loop Diagnosis Tool
# This script isolates and diagnoses the infinite loop in reasoning syntax parsing

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'
require 'timeout'

class InfiniteLoopDiagnostic
  def initialize
    @test_cases = [
      "constrain x :: Number",
      "constrain age :: Number where age > 0", 
      "constrain user.name :: String",
      "goal find_maximum(list) { postcondition: result > 0 }",
      "fact parent(john, mary)",
      "rule grandparent(X, Z) if parent(X, Y) and parent(Y, Z)"
    ]
    @loop_detected = false
    @diagnostic_results = {}
  end

  def run_diagnosis
    puts "🪲 INFINITE LOOP DIAGNOSIS STARTING"
    puts "=" * 60
    
    @test_cases.each_with_index do |test_case, index|
      puts "\n🔍 Testing Case #{index + 1}: #{test_case}"
      diagnose_test_case(test_case, index + 1)
    end
    
    puts "\n📊 DIAGNOSTIC SUMMARY"
    puts "=" * 60
    generate_diagnostic_report
  end

  private

  def diagnose_test_case(source_code, case_number)
    @diagnostic_results[case_number] = {
      source: source_code,
      status: :unknown,
      error: nil,
      parsing_steps: [],
      timeout: false,
      infinite_loop_detected: false
    }
    
    begin
      # Timeout protection - 5 seconds max per test case
      Timeout.timeout(5) do
        puts "  🔹 Tokenizing..."
        lexer = Lexer.new(source_code)
        tokens = lexer.tokenize
        
        puts "  🔹 Tokens: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(' ')}"
        @diagnostic_results[case_number][:tokens] = tokens.map { |t| "#{t.type}:#{t.value}" }
        
        puts "  🔹 Parsing with instrumentation..."
        parser = InstrumentedParser.new(tokens)
        
        result = parser.parse
        
        @diagnostic_results[case_number][:status] = :success
        @diagnostic_results[case_number][:parsing_steps] = parser.parsing_steps
        @diagnostic_results[case_number][:result_type] = result.class.name
        
        puts "  ✅ SUCCESS: #{result.class.name}"
      end
    rescue Timeout::Error => e
      @diagnostic_results[case_number][:status] = :timeout
      @diagnostic_results[case_number][:timeout] = true
      @diagnostic_results[case_number][:infinite_loop_detected] = true
      @loop_detected = true
      
      puts "  ❌ TIMEOUT: Infinite loop detected after 5 seconds"
    rescue => e
      @diagnostic_results[case_number][:status] = :error
      @diagnostic_results[case_number][:error] = e.message
      @diagnostic_results[case_number][:error_class] = e.class.name
      
      puts "  ❌ ERROR: #{e.class.name} - #{e.message}"
    end
  end

  def generate_diagnostic_report
    successful_cases = @diagnostic_results.select { |_, result| result[:status] == :success }
    timeout_cases = @diagnostic_results.select { |_, result| result[:status] == :timeout }
    error_cases = @diagnostic_results.select { |_, result| result[:status] == :error }
    
    puts "\n📈 RESULTS BREAKDOWN:"
    puts "  ✅ Successful: #{successful_cases.count}/#{@diagnostic_results.count}"
    puts "  ⏱️  Timeouts (Infinite Loops): #{timeout_cases.count}/#{@diagnostic_results.count}"
    puts "  ❌ Errors: #{error_cases.count}/#{@diagnostic_results.count}"
    
    if timeout_cases.any?
      puts "\n🚨 INFINITE LOOP CASES DETECTED:"
      timeout_cases.each do |case_num, result|
        puts "  Case #{case_num}: #{result[:source]}"
        if result[:parsing_steps] && result[:parsing_steps].any?
          puts "    Last parsing steps before timeout:"
          result[:parsing_steps].last(5).each { |step| puts "      #{step}" }
        end
      end
    end
    
    if error_cases.any?
      puts "\n❌ ERROR CASES:"
      error_cases.each do |case_num, result|
        puts "  Case #{case_num}: #{result[:source]}"
        puts "    Error: #{result[:error_class]} - #{result[:error]}"
      end
    end
    
    puts "\n🎯 CRITICAL FINDINGS:"
    analyze_critical_findings
  end

  def analyze_critical_findings
    # Look for patterns in the failures
    timeout_patterns = @diagnostic_results.select { |_, result| result[:timeout] }
                                         .map { |_, result| result[:source] }
    
    if timeout_patterns.any?
      puts "  🔍 Syntax patterns causing infinite loops:"
      timeout_patterns.each { |pattern| puts "    - #{pattern}" }
      
      # Check if specific syntax elements are problematic
      constrain_issues = timeout_patterns.select { |p| p.include?('constrain') }.any?
      goal_issues = timeout_patterns.select { |p| p.include?('goal') }.any?
      rule_issues = timeout_patterns.select { |p| p.include?('rule') }.any?
      
      puts "\n  🧩 Problematic syntax elements:"
      puts "    - CONSTRAIN syntax: #{constrain_issues ? '❌ PROBLEMATIC' : '✅ OK'}"
      puts "    - GOAL syntax: #{goal_issues ? '❌ PROBLEMATIC' : '✅ OK'}"
      puts "    - RULE syntax: #{rule_issues ? '❌ PROBLEMATIC' : '✅ OK'}"
    else
      puts "  ✅ No infinite loops detected in basic test cases"
    end
  end
end

# Instrumented Parser to track parsing steps
class InstrumentedParser < Parser
  attr_reader :parsing_steps
  
  def initialize(tokens)
    super(tokens)
    @parsing_steps = []
    @step_count = 0
    @max_steps = 1000  # Prevent runaway instrumentation
  end
  
  def advance
    @step_count += 1
    if @step_count > @max_steps
      raise "Parser step limit exceeded - infinite loop suspected"
    end
    
    old_token = @current_token&.type
    super
    new_token = @current_token&.type
    
    @parsing_steps << "Step #{@step_count}: #{old_token} -> #{new_token} (pos: #{@current_token_index})"
  end
  
  def statement
    @parsing_steps << "STATEMENT: Processing #{@current_token&.type} at position #{@current_token_index}"
    super
  end
  
  def parse_constraint
    @parsing_steps << "CONSTRAINT: Starting constraint parsing at #{@current_token&.type}"
    super
  end
  
  def parse_goal
    @parsing_steps << "GOAL: Starting goal parsing at #{@current_token&.type}"
    super  
  end
  
  def parse_rule
    @parsing_steps << "RULE: Starting rule parsing at #{@current_token&.type}"
    super
  end
  
  def expression
    @parsing_steps << "EXPRESSION: Processing expression at #{@current_token&.type}"
    super
  end
end

# Run the diagnostic
if __FILE__ == $0
  diagnostic = InfiniteLoopDiagnostic.new
  diagnostic.run_diagnosis
end