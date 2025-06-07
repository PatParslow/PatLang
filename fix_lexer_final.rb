#!/usr/bin/env ruby

# Final Fix: Lexer Test Compatibility Issues
# Issue: Two specific test failures that expect RuntimeError

puts "🔧 FINAL FIX: Lexer Test Compatibility"
puts "====================================="

# Read the current lexer file
lexer_content = File.read('src/lexer.rb')

# Fix 1: Line 409-410 - unterminated string should raise error, not return graceful token
fixed_content = lexer_content.gsub(
  /puts "Warning: Unterminated string literal starting at position #{start_position}" if \$DEBUG\s*return Token\.new\(Token::TOKEN_TYPES\[:STRING\], value, start_position, start_line, start_column\)/,
  'raise "Unterminated string literal starting at line #{start_line}, column #{start_column}"'
)

# Fix 2: Lines 201-207 - special characters should raise error, not return UNKNOWN token
# The test expects errors for '@', '$', '^', '&', '~', '`'
# Note: '#' is excluded as it's used for comments

special_char_fix = <<~'RUBY'
          # Error handling for special characters - tests expect RuntimeError
          case @current_char
          when '@', '$', '^', '&', '~', '`'
            # These should raise errors as tests expect
            error("Unexpected character '#{@current_char}' at line #{@line}, column #{@column}")
          else
            error("Unexpected character '#{@current_char}' at line #{@line}, column #{@column}")
          end
RUBY

# Replace the special character handling section
fixed_content = fixed_content.gsub(
  /# Enhanced error handling for special characters\s*case @current_char\s*when '@', '#', '\$', '\^', '&', '~', '`'\s*# Skip unsupported special characters gracefully\s*start_line, start_column = @line, @column\s*char = @current_char\s*advance\s*return Token\.new\(:UNKNOWN, char, @position - 1, start_line, start_column\)\s*else\s*error\s*end/m,
  special_char_fix.strip
)

# Also fix the error method to accept a custom message
fixed_content = fixed_content.gsub(
  /def error\s*raise "Invalid character '#\{@current_char\}' at position #\{@position\}"\s*end/,
  <<~'RUBY'.strip
    def error(message = nil)
      default_message = "Invalid character '#{@current_char}' at position #{@position}"
      raise message || default_message
    end
  RUBY
)

# Write the fixed content
File.write('src/lexer.rb', fixed_content)

puts "✅ Applied final lexer fixes:"
puts "   1. Unterminated strings now raise RuntimeError as expected"
puts "   2. Invalid special characters (@$^&~`) now raise RuntimeError as expected"
puts "   3. Enhanced error method to accept custom messages"
puts "   4. Maintained comment handling (#) as graceful"
puts