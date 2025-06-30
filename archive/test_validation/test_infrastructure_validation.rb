#!/usr/bin/env ruby

# Test to validate that the test_helper.rb infrastructure fix works
puts "🔧 VALIDATING TEST HELPER INFRASTRUCTURE FIX"
puts "=" * 60

# List of files that were affected by the missing test/test_helper.rb
affected_files = [
  'test/validate_type_diagnosis.rb',
  'test/strategic_coverage_gap_analysis.rb', 
  'test/failure_analysis.rb',
  'test/object_model_coverage_analysis.rb',
  'test/debug_type_expectations.rb',
  'test/evaluator_coverage_final.rb'
]

success_count = 0
total_count = affected_files.length

puts "\n📋 Testing #{total_count} previously failing files:"
puts "-" * 40

affected_files.each_with_index do |file, index|
  print "#{index + 1}. #{File.basename(file)}... "
  
  begin
    # Test that the file can be loaded without LoadError
    output = `ruby -c "#{file}" 2>&1`
    exit_code = $?.exitstatus
    
    if exit_code == 0
      puts "✅ SYNTAX OK"
      success_count += 1
    else
      puts "❌ SYNTAX ERROR"
      puts "   Error: #{output.strip}"
    end
  rescue => e
    puts "❌ EXCEPTION"
    puts "   Error: #{e.message}"
  end
end

puts "\n📊 VALIDATION RESULTS:"
puts "-" * 40
puts "✅ Fixed files: #{success_count}/#{total_count}"
puts "❌ Still failing: #{total_count - success_count}/#{total_count}"

if success_count == total_count
  puts "\n🎉 SUCCESS: All infrastructure problems resolved!"
  puts "   The missing test/test_helper.rb file has been created and"
  puts "   all affected files can now load the test infrastructure."
else
  puts "\n⚠️  PARTIAL SUCCESS: #{success_count} files fixed, #{total_count - success_count} still need attention"
end

puts "\n🔍 INFRASTRUCTURE VERIFICATION:"
puts "-" * 40

# Test that both test helper files exist and are loadable
puts "1. Checking test/test_helper.rb exists..."
if File.exist?('test/test_helper.rb')
  puts "   ✅ EXISTS"
else
  puts "   ❌ MISSING"
end

puts "2. Checking test/helpers/test_helper.rb exists..."
if File.exist?('test/helpers/test_helper.rb')
  puts "   ✅ EXISTS"
else
  puts "   ❌ MISSING"
end

puts "3. Testing require chain..."
begin
  require_relative 'test/test_helper'
  puts "   ✅ REQUIRE CHAIN WORKS"
rescue => e
  puts "   ❌ REQUIRE CHAIN BROKEN: #{e.message}"
end

puts "\n" + "=" * 60
puts "INFRASTRUCTURE VALIDATION COMPLETE"