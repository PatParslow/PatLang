#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'

# Script to validate that our parser can handle the complete reasoning syntax examples
def validate_reasoning_file(filename)
  puts "Validating #{filename}..."
  puts "="*50
  
  begin
    # Read the example file
    content = File.read(filename)
    
    # Split into individual statements (simple approach - split by lines that don't start with # or whitespace)
    lines = content.split("\n")
    statements = []
    current_statement = ""
    
    lines.each do |line|
      # Skip empty lines and comments
      next if line.strip.empty? || line.strip.start_with?('#')
      
      # If line starts without indentation, it's a new statement
      if line =~ /^\S/ && !current_statement.empty?
        statements << current_statement.strip
        current_statement = line
      else
        current_statement += "\n" + line
      end
    end
    
    # Add the last statement
    statements << current_statement.strip unless current_statement.empty?
    
    puts "Found #{statements.length} reasoning statements to parse"
    puts
    
    parsed_count = 0
    error_count = 0
    
    statements.each_with_index do |statement, index|
      next if statement.empty?
      
      puts "#{index + 1}. Parsing: #{statement.split("\n").first[0..60]}#{'...' if statement.length > 60}"
      
      begin
        lexer = Lexer.new(statement)
        tokens = lexer.tokenize
        parser = Parser.new(tokens)
        ast = parser.parse
        
        if ast.is_a?(ErrorNode)
          puts "   ERROR: #{ast.message}"
          error_count += 1
        else
          puts "   SUCCESS: #{ast.class.name}"
          parsed_count += 1
        end
      rescue => e
        puts "   EXCEPTION: #{e.message}"
        error_count += 1
      end
      
      puts
    end
    
    puts "="*50
    puts "Validation Results:"
    puts "Successfully parsed: #{parsed_count}"
    puts "Errors/Exceptions: #{error_count}"
    puts "Total statements: #{statements.length}"
    puts "Success rate: #{((parsed_count.to_f / statements.length) * 100).round(1)}%"
    
    if error_count == 0
      puts "\n🎉 ALL REASONING SYNTAX PATTERNS PARSED SUCCESSFULLY!"
    else
      puts "\n⚠️  Some syntax patterns need attention."
    end
    
  rescue => e
    puts "Failed to read or process file: #{e.message}"
  end
end

# Validate our example file
validate_reasoning_file('examples/unified_reasoning_syntax_examples.patlang')