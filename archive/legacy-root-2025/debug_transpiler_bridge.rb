#!/usr/bin/env ruby

# Debug version to find where transpiler_bridge stops executing

puts "=== DEBUG: Starting transpiler bridge debug ==="

begin
  puts "DEBUG: Step 1 - Loading dependencies"
  require 'fileutils'
  require 'tmpdir'
  require 'open3'
  puts "DEBUG: Step 1 - Dependencies loaded successfully"
  
  puts "DEBUG: Step 2 - Loading native evaluator ruby bridge"
  require_relative 'native_evaluator/ruby_bridge'
  puts "DEBUG: Step 2 - Native evaluator loaded successfully"
  
  puts "DEBUG: Step 3 - Creating PaTLangPhase1Bridge instance"
  phase1_bridge = PaTLangPhase1Bridge.new
  puts "DEBUG: Step 3 - PaTLangPhase1Bridge created successfully"
  
  puts "DEBUG: Step 4 - Testing phase1_bridge evaluate method"
  test_result = phase1_bridge.evaluate("1 + 1", prefer_patlang: false)
  puts "DEBUG: Step 4 - Phase1 evaluate test: #{test_result[:success] ? 'SUCCESS' : 'FAILED'}"
  
  puts "DEBUG: Step 5 - Loading transpiler files"
  transpiler_source = File.read(File.join('transpiler', 'core_transpiler.patlang'))
  templates_source = File.read(File.join('transpiler', 'code_templates.patlang'))
  puts "DEBUG: Step 5 - Transpiler files loaded (#{transpiler_source.length + templates_source.length} chars)"
  
  puts "DEBUG: Step 6 - Testing transpiler source evaluation"
  combined_source = transpiler_source + "\n\n" + templates_source
  eval_result = phase1_bridge.evaluate(combined_source, prefer_patlang: true)
  puts "DEBUG: Step 6 - Transpiler evaluation: #{eval_result[:success] ? 'SUCCESS' : 'FAILED'}"
  if !eval_result[:success]
    puts "DEBUG: Error: #{eval_result[:error]}"
  end
  
  puts "DEBUG: All steps completed successfully"
  
rescue => e
  puts "DEBUG: Exception caught at step: #{e.message}"
  puts "DEBUG: Backtrace:"
  puts e.backtrace.first(10)
end

puts "=== DEBUG: Debug script completed ==="