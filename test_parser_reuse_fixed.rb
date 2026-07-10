require_relative "patlang-core/lexer/lexer"
require_relative "patlang-core/parser/parser"

# Test with correct grammar (with "called")
content = "make a class called Test inherits BaseObject { make a function called hello { } }"

5.times do |i|
  begin
    lexer = Patlang::Lexer::Lexer.new(content)
    tokens = lexer.tokenize
    parser = Patlang::Parser::Parser.new(tokens)
    ast = parser.parse
    puts "Run #{i+1}: SUCCESS - #{ast.statements.size} statements"
  rescue => e
    puts "Run #{i+1}: FAILED - #{e.message}"
  end
end