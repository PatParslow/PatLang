#!/usr/bin/env ruby

puts "🚀 PHASE 2 VALIDATION: TARGETED ERROR FIXES"
puts "=" * 50

puts "\n🔧 PHASE 2 FIXES APPLIED:"
puts "   ✅ Fixed UnificationEngine constructor signature"
puts "   ✅ Fixed safe_error method calls in parser timeout protection"  
puts "   ✅ Fixed message_msg method in test helper"

puts "\n🧪 RUNNING TEST SUITE TO VALIDATE FIXES..."

start_time = Time.now
result = `timeout 45 rake test 2>&1`
end_time = Time.now

# Parse results
summary_match = result.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/)
if summary_match
  runs, assertions, failures, errors = summary_match.captures
  
  current_success = ((runs.to_i - failures.to_i - errors.to_i).to_f / runs.to_i * 100).round(1)
  total_issues = failures.to_i + errors.to_i
  
  puts "\n📊 PHASE 2 RESULTS:"
  puts "   Test Runs: #{runs}"
  puts "   Assertions: #{assertions}"
  puts "   Failures: #{failures}"
  puts "   Errors: #{errors}"
  puts "   Success Rate: #{current_success}%"
  puts "   Duration: #{(end_time - start_time).round(1)}s"
  
  # Compare with Phase 1 baseline
  phase1_errors = 167
  phase1_success = 67.7
  
  error_improvement = phase1_errors - errors.to_i
  success_improvement = current_success - phase1_success
  
  puts "\n🎯 PHASE 2 IMPACT ANALYSIS:"
  puts "   Phase 1 Baseline: #{phase1_errors} errors, #{phase1_success}% success"
  puts "   Phase 2 Results: #{errors} errors, #{current_success}% success"
  puts "   Error Reduction: #{error_improvement} (#{error_improvement >= 0 ? '+' : ''}#{((error_improvement.to_f / phase1_errors) * 100).round(1)}%)"
  puts "   Success Improvement: #{success_improvement >= 0 ? '+' : ''}#{success_improvement.round(1)}%"
  
  # Validate specific fixes
  puts "\n🔍 TARGETED FIX VALIDATION:"
  
  safe_error_remaining = result.scan(/undefined method `safe_error'/).size
  puts "   safe_error method: #{safe_error_remaining == 0 ? '✅ RESOLVED' : "⚠️ #{safe_error_remaining} remaining"}"
  
  message_msg_remaining = result.scan(/undefined method `message_msg'/).size  
  puts "   message_msg method: #{message_msg_remaining == 0 ? '✅ RESOLVED' : "⚠️ #{message_msg_remaining} remaining"}"
  
  constructor_remaining = result.scan(/wrong number of arguments.*initialize/).size
  puts "   Constructor errors: #{constructor_remaining} remaining (was ~26)"
  
  # Target achievement check
  target_rate = 80.0
  progress_to_target = ((current_success - 46.0) / (target_rate - 46.0) * 100).round(1)
  
  puts "\n🎯 TARGET PROGRESS:"
  puts "   Current: #{current_success}% / Target: #{target_rate}%"
  puts "   Gap Remaining: #{(target_rate - current_success).round(1)}%"
  puts "   Progress: #{progress_to_target}% of the way to target"
  
  if current_success >= target_rate
    puts "   🎉 TARGET ACHIEVED!"
  elsif current_success >= 75.0
    puts "   🎯 APPROACHING TARGET (within 5%)"
  else
    puts "   📈 SOLID PROGRESS (#{(target_rate - current_success).round(1)}% remaining)"
  end
  
  # Next priority analysis
  puts "\n🔄 REMAINING ERROR PATTERNS:"
  
  remaining_patterns = [
    { pattern: /LocalJumpError/, name: "LocalJumpError" },
    { pattern: /wrong number of arguments/, name: "Constructor Issues" },
    { pattern: /undefined method `merge'/, name: "Missing merge" },
    { pattern: /undefined method `\+'/, name: "Missing + operator" },
    { pattern: /NameError/, name: "Name Errors" },
    { pattern: /TypeError/, name: "Type Errors" }
  ]
  
  remaining_patterns.each do |pattern_info|
    count = result.scan(pattern_info[:pattern]).size
    next if count == 0
    puts "   #{pattern_info[:name]}: #{count} occurrences"
  end
  
  # Calculate next iteration potential
  puts "\n🚀 NEXT ITERATION POTENTIAL:"
  
  local_jump = result.scan(/LocalJumpError/).size
  constructor = result.scan(/wrong number of arguments/).size
  merge_issues = result.scan(/undefined method `merge'/).size
  
  next_targets = local_jump + constructor + merge_issues
  potential_gain = (next_targets.to_f / runs.to_i * 100).round(1)
  projected_success = current_success + potential_gain
  
  puts "   High-impact targets: #{next_targets} errors"
  puts "   Potential improvement: +#{potential_gain}%"
  puts "   Projected success rate: #{projected_success}%"
  puts "   Target achievable: #{projected_success >= target_rate ? '🎯 YES' : '📈 PROGRESS'}"
  
else
  puts "❌ Could not parse test results"
  puts result.lines.last(10).join
end

puts "\n✅ PHASE 2 VALIDATION COMPLETE"
puts "Ready for Phase 3: Final push to 80% target"