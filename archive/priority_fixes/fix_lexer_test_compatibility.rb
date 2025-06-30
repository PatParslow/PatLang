#!/usr/bin/env ruby

# Fix: Lexer Test Compatibility 
# Issue: Tests expect RuntimeError for some cases, but lexer became too graceful

puts "🔧 FIX: Lexer Test Compatibility"
puts "================================"

# Read the current lexer file
lexer_content = File.read('src/lexer.rb')

# The issue is that my fix made unterminated strings return gracefully,
# but the test on line 242 expects an error for '"unclosed string'

# Need to find a balance: graceful for some cases, but still error for others
# Looking at the test, it specifically tests '"unclosed string' - so we need
# to be more selective about when to be graceful

# Update the tokenize_string method to still raise errors for completely unterminated strings
improved_tokenize_string = <<~'RUBY'
  def tokenize_string(quote_type = '"')
    start_position = @position
    start_line, start_column = @line, @column
    advance  # Skip opening quote
    value = ""
    
    while @current_char && @current_char != quote_type
      if @current_char == '\\'
        # Handle escape sequences
        advance
        if @current_char
          case @current_char
          when 'n'
            value += "\n"
          when 't'
            value += "\t"
          when 'r'
            value += "\r"
          when '\\'
            value += "\\"
          when '"'
            value += '"'
          when "'"
            value += "'"
          else
            value += @current_char
          end
          advance
        else
          # For incomplete escape sequences at end of input, still raise error
          raise "Incomplete escape sequence at end of string at line #{@line}, column #{@column}"
        end
      else
        value += @current_char
        advance
      end
    end
    
    if @current_char != quote_type
      # FIXED: For completely unterminated strings (no closing quote), raise error as tests expect
      # Only be graceful for edge cases in actual parsing, not basic syntax errors
      raise "Unterminated string literal starting at line #{start_line}, column #{start_column}"
    end
    
    advance  # Skip closing quote
    Token.new(Token::TOKEN_TYPES[:STRING], value, start_position, start_line, start_column)
  end
RUBY

# Replace the tokenize_string method
fixed_content = lexer_content.gsub(
  /def tokenize_string\(quote_type = '\"'\).*?end/m,
  improved_tokenize_string.strip
)

# Also need to make sure the comprehensive error handling still raises errors for invalid chars
# The test on line 569 expects errors for '@', '$', '^', '&', '~', '`'

# Update the error handling to be more selective - only be graceful for very specific cases
enhanced_error_handling = <<~'RUBY'
        else
          # Error handling for special characters - some should still raise errors
          case @current_char
          when '@', '$', '^', '&', '~', '`'
            # These should raise errors as tests expect
            error("Unexpected character '#{@current_char}' at line #{@line}, column #{@column}")
          when "\0", "\x01".."\x08", "\x0B", "\x0C", "\x0E".."\x1F"
            # Handle control characters gracefully with warning
            start_line, start_column = @line, @column
            char = @current_char
            puts "Warning: Control character (ASCII #{char.ord}) at line #{@line}, column #{@column}" if $DEBUG
            advance
            return Token.new(:UNKNOWN, "CTRL(#{char.ord})", @position - 1, start_line, start_column)
          else
            error("Unexpected character '#{@current_char}' at line #{@line}, column #{@column}")
          end
RUBY

# Replace the error handling section
fixed_content = fixed_content.gsub(
  /else\s*# Error handling for special characters.*?end\s*end/m,
  enhanced_error_handling.strip + "\n        end"
)

# Write the fixed content
File.write('src/lexer.rb', fixed_content)

puts "✅ Fixed Lexer test compatibility issues"
puts "   - Unterminated strings now raise errors as tests expect"
puts "   - Invalid characters (@$^&~`) still raise errors"
puts "   - Maintained graceful handling for appropriate edge cases"
puts "   - Tests should now pass while keeping error recovery improvements"
puts