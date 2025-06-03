#!/usr/bin/env ruby

require_relative 'src/lexer'

def test_invalid_chars
  invalid_inputs = ['@', '$', '%', '^', '&', '~', '`']
  
  invalid_inputs.each do |invalid_char|
    begin
      lexer = Lexer.new(invalid_char)
      result = lexer.tokenize
      puts "#{invalid_char}: SUCCESS - tokens: #{result.map(&:type)}"
    rescue => e
      puts "#{invalid_char}: ERROR - #{e.class}: #{e.message}"
    end
  end
end

test_invalid_chars