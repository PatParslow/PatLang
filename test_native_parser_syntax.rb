#!/usr/bin/env ruby

# Test script to verify native parser PaTLang files have correct syntax
# This will help confirm the "Missing 'end' to close function body" warnings are resolved

require_relative 'native_parser_bridge'

def test_native_parser_syntax
  puts "🧪 Testing Native Parser PaTLang File Syntax..."
  
  # Test files that were fixed
  test_files = [
    'native_parser/native_parser.patlang',
    'native_parser/core/grammar_engine.patlang',
    'native_parser/core/ast_system.patlang'
  ]
  
  # Track warnings/errors
  warnings_found = 0
  errors_found = 0
  
  test_files.each do |file_path|
    puts "\n📄 Testing: #{file_path}"
    
    begin
      # Test loading the file through the native parser bridge
      # This should trigger any syntax warnings/errors
      result = NativeParserBridge.load_patlang_file(file_path)
      
      if result[:success]
        puts "  ✅ Successfully loaded without syntax errors"
      else
        puts "  ❌ Failed to load: #{result[:error]}"
        errors_found += 1
      end
      
      # Check for warnings in the result
      if result[:warnings] && !result[:warnings].empty?
        result[:warnings].each do |warning|
          if warning.include?("Missing 'end' to close function body")
            puts "  ⚠️  WARNING: #{warning}"
            warnings_found += 1
          end
        end
      end
      
    rescue => e
      puts "  ❌ Exception during loading: #{e.message}"
      errors_found += 1
    end
  end
  
  puts "\n📊 Test Results Summary:"
  puts "  • Files tested: #{test_files.length}"
  puts "  • Syntax errors: #{errors_found}"
  puts "  • 'Missing end' warnings: #{warnings_found}"
  
  if warnings_found == 0 && errors_found == 0
    puts "  ✅ All native parser files have correct syntax!"
    return true
  else
    puts "  ❌ Issues found that need attention"
    return false
  end
end

# Run the test
if __FILE__ == $0
  success = test_native_parser_syntax
  exit(success ? 0 : 1)
end