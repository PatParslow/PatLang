# Read the lexer file
content = File.read('src/lexer.rb')

# Find where to add the comment case
lines = content.split("\n")

# Find the line with the colon case and add comment case after it
new_lines = []
i = 0
while i < lines.length
  new_lines << lines[i]
  
  # After the colon case, add comment handling
  if lines[i].strip == 'return Token.new(Token::TOKEN_TYPES[:COLON], \':\', @position - 1)'
    new_lines << "      when '#'"
    new_lines << "        # Skip comment until end of line"
    new_lines << "        while @current_char && @current_char != \"\\n\""
    new_lines << "          advance"
    new_lines << "        end"
    new_lines << "        # Skip the newline too if present"
    new_lines << "        if @current_char == \"\\n\""
    new_lines << "          advance"
    new_lines << "        end"
    new_lines << "        return get_next_token  # Get next non-comment token"
  end
  
  i += 1
end

# Write the fixed content
File.write('src/lexer.rb', new_lines.join("\n"))
puts "Fixed comment handling in lexer"
