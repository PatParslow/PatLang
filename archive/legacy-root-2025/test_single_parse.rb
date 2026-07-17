require_relative "patlang-core/lexer/lexer"
require_relative "patlang-core/parser/parser"

content = 'make a class Test inherits BaseObject { make a function called hello { } }'

lexer = Patlang::Lexer::Lexer.new(content)
tokens = lexer.tokenize
parser = Patlang::Parser::Parser.new(tokens)
ast = parser.parse
puts "Single run: #{ast.statements.size} statements"