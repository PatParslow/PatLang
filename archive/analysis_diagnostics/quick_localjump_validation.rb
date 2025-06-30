#!/usr/bin/env ruby

puts "🔧 QUICK VALIDATION: LocalJumpError Fix"
puts "=" * 40

puts "\n🧪 Testing LocalJumpError fix..."

# Quick test run focusing on LocalJumpError
result = `timeout 30 rake test 2>&1`

local_jump_count = result.scan(/LocalJumpError/).size
puts "   LocalJumpError count: #{local_jump_count} (was 86)"

if local_jump_count < 86
  puts "   ✅ LocalJumpError REDUCED by #{86 - local_jump_count}"
else
  puts "   ⚠️  LocalJumpError unchanged"
end

# Check overall impact
summary_match = result.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/)
if summary_match
  runs, assertions, failures, errors = summary_match.captures
  current_success = ((runs.to_i - failures.to_i - errors.to_i).to_f / runs.to_i * 100).round(1)
  puts "   Current success rate: #{current_success}% (was 68.0%)"
  
  if current_success > 68.0
    puts "   🎯 SUCCESS RATE IMPROVED!"
  end
end

puts "\n✅ QUICK VALIDATION COMPLETE"