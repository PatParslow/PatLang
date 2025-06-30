#!/usr/bin/env ruby

# Fix 3: Lexer Error Recovery
# Issue: Unterminated strings and error handling need improvement

puts "🔧 FIX 3: Lexer Error Recovery"
puts "=============================="

# Read the current lexer file
lexer_content = File.read('src/lexer.rb')

# Improve the tokenize_string method for better error recovery
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
          # IMPROVED: Better handling of incomplete escape sequences
          puts "Warning: Incomplete escape sequence at end of string (line #{@line})" if $DEBUG
          # Return the string token with what we have
          return Token.new(Token::TOKEN_TYPES[:STRING], value, start_position, start_line, start_column)
        end
      else
        value += @current_char
        advance
      end
    end
    
    if @current_char != quote_type
      # IMPROVED: Enhanced unterminated string handling
      puts "Warning: Unterminated string literal starting at line #{start_line}, column #{start_column}" if $DEBUG
      # For unterminated strings, we still return a valid STRING token
      # This allows the parser to continue processing rather than failing completely
      return Token.new(Token::TOKEN_TYPES[:STRING], value, start_position, start_line, start_column)
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

# Improve the error method for better error reporting
improved_error_method = <<~'RUBY'
  def error(message = nil)
    context = ""
    if @position > 0
      start_pos = [@position - 10, 0].max
      end_pos = [@position + 10, @text.length].min
      context = " Context: '#{@text[start_pos...end_pos]}'"
    end
    
    default_message = "Invalid character '#{@current_char}' at line #{@line}, column #{@column}#{context}"
    raise "#{message || default_message}"
  end
RUBY

# Replace the error method
fixed_content = fixed_content.gsub(
  /def error.*?end/m,
  improved_error_method.strip
)

# Improve special character handling in get_next_token
enhanced_error_handling = <<~'RUBY'
        else
          # Enhanced error handling for special characters
          case @current_char
          when '@', '$', '^', '&', '~', '`'
            # Skip unsupported special characters gracefully with better error reporting
            start_line, start_column = @line, @column
            char = @current_char
            puts "Warning: Unsupported special character '#{char}' at line #{@line}, column #{@column}" if $DEBUG
            advance
            return Token.new(:UNKNOWN, char, @position - 1, start_line, start_column)
          when "\0", "\x01".."\x08", "\x0B", "\x0C", "\x0E".."\x1F"
            # Handle control characters gracefully
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
  /else\s*# Enhanced error handling for special characters.*?end\s*end/m,
  enhanced_error_handling.strip + "\n        end"
)

# Write the fixed content
File.write('src/lexer.rb', fixed_content)

puts "✅ Fixed Lexer error recovery issues"
puts "   - Improved unterminated string handling"
puts "   - Enhanced error messages with context"
puts "   - Better special character handling"
puts "   - Added control character detection"
puts