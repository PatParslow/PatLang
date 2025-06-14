#!/usr/bin/env ruby

puts "🔍 QUICK SUCCESS RATE CHECK"
puts "=" * 30

puts "\n🧪 Running direct test command..."

# Run tests directly with timeout
result = `timeout 60 rake test 2>&1`

# Extract the final test summary
lines = result.lines
summary_line = lines.reverse.find { |line| line.match(/\d+ runs, \d+ assertions, \d+ failures, \d+ errors/) }

if summary_line
  puts "\n📊 TEST RESULTS:"
  puts "   #{summary_line.strip}"
  
  # Parse the numbers
  if summary_line.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/)
    runs, assertions, failures, errors = $1.to_i, $2.to_i, $3.to_i, $4.to_i
    
    success_rate = ((runs - failures - errors).to_f / runs * 100).round(1)
    total_issues = failures + errors
    
    puts "   Success Rate: #{success_rate}%"
    puts "   Total Issues: #{total_issues}"
    
    if success_rate >= 80.0
      puts "\n🎉 🏆 80% TARGET ACHIEVED! 🏆 🎉"
      puts "   BREAKTHROUGH SUCCESS: #{success_rate}%"
    elsif success_rate > 77.5
      puts "\n📈 PROGRESS MADE!"
      puts "   Improvement from 77.5%: +#{(success_rate - 77.5).round(1)}%"
      puts "   Gap to 80%: #{(80.0 - success_rate).round(1)}%"
    else
      puts "\n📊 Current: #{success_rate}%"
    end
    
    # Compare with our journey
    original_errors = 419
    error_reduction = original_errors - total_issues
    error_reduction_percent = (error_reduction.to_f / original_errors * 100).round(1)
    
    puts "\n🎯 CAMPAIGN PROGRESS:"
    puts "   Original errors: #{original_errors}"
    puts "   Current errors: #{total_issues}"
    puts "   Errors eliminated: #{error_reduction} (#{error_reduction_percent}%)"
    
  end
else
  puts "\n⚠️  Could not find test summary in output"
  puts "Last few lines of output:"
  puts result.lines.last(5).join
end

puts "\n✅ CHECK COMPLETE"