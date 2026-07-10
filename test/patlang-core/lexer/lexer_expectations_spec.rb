# frozen_string_literal: true

require_relative '../../test_helper'
require_relative '../../../patlang-core/lexer/lexer'

module Patlang
  module Lexer
    RSpec.describe Lexer do
      describe "expectation-driven tokenization" do
        context "keyword vs identifier disambiguation" do
          it "tokenizes 'is' as IS_KEYWORD when expected in assignment context" do
            lexer = Lexer.new("x is 42")
            tokens = lexer.tokenize(expectations: [TokenType::IS_KEYWORD, TokenType::INTEGER_LITERAL])
            
            expect(tokens.map(&:type)).to eq([
              TokenType::IDENTIFIER,  # x
              TokenType::IS_KEYWORD,  # is
              TokenType::INTEGER_LITERAL, # 42
              TokenType::EOF
            ])
            
            expect(tokens[1].value).to eq("is")
          end
          
          it "tokenizes 'is' as IDENTIFIER when expected as variable name" do
            lexer = Lexer.new("is_valid")
            tokens = lexer.tokenize(expectations: [TokenType::IDENTIFIER])
            
            expect(tokens.map(&:type)).to eq([
              TokenType::IDENTIFIER,
              TokenType::EOF
            ])
            
            expect(tokens[0].value).to eq("is_valid")
          end
          
          it "tokenizes 'make' as MAKE_KEYWORD when expected after newline" do
            lexer = Lexer.new("make a function")
            tokens = lexer.tokenize(expectations: [TokenType::MAKE_KEYWORD, TokenType::ARTICLE])
            
            expect(tokens[0].type).to eq(TokenType::MAKE_KEYWORD)
            expect(tokens[0].value).to eq("make")
          end
          
          it "tokenizes 'a' and 'an' as ARTICLE when expected" do
            %w[a an].each do |article|
              lexer = Lexer.new("#{article} function")
              tokens = lexer.tokenize(expectations: [TokenType::ARTICLE, TokenType::FUNCTION_KW])
              
              expect(tokens[0].type).to eq(TokenType::ARTICLE)
              expect(tokens[0].value).to eq(article)
            end
          end
          
          it "tokenizes 'when' as WHEN_KEYWORD in event handler context" do
            lexer = Lexer.new("when user:login")
            tokens = lexer.tokenize(expectations: [TokenType::WHEN_KEYWORD, TokenType::IDENTIFIER])
            
            expect(tokens[0].type).to eq(TokenType::WHEN_KEYWORD)
            expect(tokens[0].value).to eq("when")
          end
          
          it "tokenizes 'then' as THEN_KEYWORD in if-statement context" do
            lexer = Lexer.new("if x then y end")
            tokens = lexer.tokenize(expectations: [TokenType::IF_KW, TokenType::IDENTIFIER, TokenType::THEN_KEYWORD])
            
            then_token = tokens.find { |t| t.type == TokenType::THEN_KEYWORD }
            expect(then_token).not_to be_nil
            expect(then_token.value).to eq("then")
          end
        end
        
        context "block delimiter expectations" do
          it "tokenizes '{' as BLOCK_START in function body context" do
            lexer = Lexer.new("make a function called foo { body }")
            tokens = lexer.tokenize(expectations: [
              TokenType::MAKE_KEYWORD, TokenType::ARTICLE, TokenType::FUNCTION_KW,
              TokenType::CALLED, TokenType::IDENTIFIER, TokenType::BLOCK_START
            ])
            
            block_start = tokens.find { |t| t.type == TokenType::BLOCK_START }
            expect(block_start).not_to be_nil
            expect(block_start.value).to eq("{")
          end
          
          it "tokenizes '|' as BLOCK_PARAM_START in lambda context" do
            lexer = Lexer.new("|x, y| x + y")
            tokens = lexer.tokenize(expectations: [TokenType::BLOCK_PARAM_START, TokenType::IDENTIFIER])
            
            param_start = tokens.find { |t| t.type == TokenType::BLOCK_PARAM_START }
            expect(param_start).not_to be_nil
            expect(param_start.value).to eq("|")
          end
        end
        
        context "event specification expectations" do
          it "tokenizes ':' as EVENT_ACTION_SPECIFIER after event name" do
            lexer = Lexer.new("when user:login { }")
            tokens = lexer.tokenize(expectations: [
              TokenType::WHEN_KEYWORD, TokenType::IDENTIFIER, 
              TokenType::EVENT_ACTION_SPECIFIER, TokenType::IDENTIFIER
            ])
            
            spec = tokens.find { |t| t.type == TokenType::EVENT_ACTION_SPECIFIER }
            expect(spec).not_to be_nil
            expect(spec.value).to eq(":")
          end
          
          it "tokenizes event action keywords after ':'" do
            %w[called completed error changed activated].each do |action|
              lexer = Lexer.new("when foo:#{action} { }")
              tokens = lexer.tokenize
              
              # Event action keywords are tokenized as specific types
              action_kw = tokens.find { |t| [TokenType::CALLED, TokenType::COMPLETED, TokenType::ERROR_KEYWORD, TokenType::CHANGED, TokenType::ACTIVATED].include?(t.type) }
              expect(action_kw).not_to be_nil
              expect(action_kw.value).to eq(action)
            end
          end
        end
        
        context "assignment/mutation context expectations" do
          it "recognizes 'is' as binding keyword in declaration context" do
            lexer = Lexer.new("x is 42")
            tokens = lexer.tokenize(expectations: [
              TokenType::IDENTIFIER, TokenType::IS_KEYWORD, TokenType::INTEGER_LITERAL
            ])
            
            is_token = tokens.find { |t| t.type == TokenType::IS_KEYWORD }
            expect(is_token).not_to be_nil
            expect(is_token.value).to eq("is")
          end
          
          it "recognizes 'becomes' as mutation keyword" do
            lexer = Lexer.new("x becomes 43")
            tokens = lexer.tokenize(expectations: [
              TokenType::IDENTIFIER, TokenType::BECOMES_KEYWORD, TokenType::INTEGER_LITERAL
            ])
            
            becomes = tokens.find { |t| t.type == TokenType::BECOMES_KEYWORD }
            expect(becomes).not_to be_nil
            expect(becomes.value).to eq("becomes")
          end
        end
        
        context "function declaration expectations" do
          it "expects ARTICLE after 'make'" do
            lexer = Lexer.new("make a function")
            tokens = lexer.tokenize(expectations: [
              TokenType::MAKE_KEYWORD, TokenType::ARTICLE
            ])
            expect(tokens[1].type).to eq(TokenType::ARTICLE)
          end
          
          it "expects declaration type keyword after article" do
            %w[function class template goal list].each do |type|
              lexer = Lexer.new("make a #{type}")
              tokens = lexer.tokenize
              decl_type = tokens.find { |t| [TokenType::FUNCTION_KW, TokenType::CLASS_KW, TokenType::TEMPLATE_KW, TokenType::GOAL_KW, TokenType::LIST_KW].include?(t.type) }
              expect(decl_type).not_to be_nil
              expect(decl_type.value).to eq(type)
            end
          end
          
          it "expects CALLED after declaration type" do
            lexer = Lexer.new("make a function called")
            tokens = lexer.tokenize
            expect(tokens[3].type).to eq(TokenType::CALLED)
          end
        end
        
        context "function body expectations" do
          it "expects TAKES, RETURNS, REQUIRES, ENSURES, or BLOCK_END in function body" do
            lexer = Lexer.new("make a function called foo { takes: x returns: x }")
            tokens = lexer.tokenize
            
            expect(tokens.any? { |t| t.type == TokenType::TAKES_KEYWORD }).to be true
            expect(tokens.any? { |t| t.type == TokenType::RETURNS_KEYWORD }).to be true
            expect(tokens.any? { |t| t.type == TokenType::BLOCK_END }).to be true
          end
        end
        
        context "control flow expectations" do
          it "recognizes 'if', 'then', 'elsif', 'else', 'end'" do
            lexer = Lexer.new("if x then y else z end")
            tokens = lexer.tokenize
            
            expect(tokens.any? { |t| t.type == TokenType::IF_KW }).to be true
            expect(tokens.any? { |t| t.type == TokenType::THEN_KEYWORD }).to be true
            expect(tokens.any? { |t| t.type == TokenType::ELSE_KEYWORD }).to be true
            expect(tokens.any? { |t| t.type == TokenType::END_KEYWORD }).to be true
          end
        end
        
        context "activation expectations" do
          it "expects identifier after 'activate'" do
            lexer = Lexer.new("activate my_goal")
            tokens = lexer.tokenize(expectations: [
              TokenType::ACTIVATE_KEYWORD, TokenType::IDENTIFIER
            ])
            
            expect(tokens[0].type).to eq(TokenType::ACTIVATE_KEYWORD)
            expect(tokens[1].type).to eq(TokenType::IDENTIFIER)
          end
          
          it "recognizes 'with' in activation" do
            lexer = Lexer.new("activate foo with bar")
            tokens = lexer.tokenize(expectations: [
              TokenType::ACTIVATE_KEYWORD, TokenType::IDENTIFIER, TokenType::WITH_KEYWORD, TokenType::IDENTIFIER
            ])
            
            with_kw = tokens.find { |t| t.type == TokenType::WITH_KEYWORD }
            expect(with_kw).not_to be_nil
            expect(with_kw.value).to eq("with")
          end
        end
      end
      
      describe "literals and basic tokens" do
        it "tokenizes integers" do
          lexer = Lexer.new("42")
          tokens = lexer.tokenize
          expect(tokens[0].type).to eq(TokenType::INTEGER_LITERAL)
          expect(tokens[0].value).to eq(42)
        end
        
        it "tokenizes floats" do
          lexer = Lexer.new("3.14")
          tokens = lexer.tokenize
          expect(tokens[0].type).to eq(TokenType::FLOAT_LITERAL)
          expect(tokens[0].value).to eq(3.14)
        end
        
        it "tokenizes strings with escapes" do
          lexer = Lexer.new('"hello\\nworld"')
          tokens = lexer.tokenize
          expect(tokens[0].type).to eq(TokenType::STRING_LITERAL)
          expect(tokens[0].value).to eq("hello\nworld")
        end
        
        it "tokenizes operators" do
          lexer = Lexer.new("+ - * / % = != < > <= >=")
          tokens = lexer.tokenize
          types = tokens.map(&:type).reject { |t| t == TokenType::EOF }
          expect(types).to eq([
            TokenType::PLUS, TokenType::MINUS, TokenType::STAR, TokenType::SLASH,
            TokenType::PERCENT, TokenType::EQ, TokenType::NEQ, TokenType::LT,
            TokenType::GT, TokenType::LTE, TokenType::GTE
          ])
        end
        
        it "tokenizes delimiters" do
          lexer = Lexer.new("() {} [] , . ; =>")
          tokens = lexer.tokenize
          types = tokens.map(&:type).reject { |t| t == TokenType::EOF }
          expect(types).to eq([
            TokenType::LPAREN, TokenType::RPAREN,
            TokenType::BLOCK_START, TokenType::BLOCK_END,
            TokenType::LBRACKET, TokenType::RBRACKET,
            TokenType::COMMA, TokenType::DOT, TokenType::SEMICOLON, TokenType::ARROW
          ])
        end
      end
      
      describe "error handling" do
        it "reports unrecognized characters with position" do
          lexer = Lexer.new("@")
          expect { lexer.tokenize }.to raise_error(LexerError, /Unexpected character '@'/)
        end
        
        it "reports unterminated strings" do
          lexer = Lexer.new('"unterminated')
          expect { lexer.tokenize }.to raise_error(LexerError, /Unterminated string/)
        end
        
        it "includes line/column in token metadata" do
          lexer = Lexer.new("x is 42")
          tokens = lexer.tokenize
          
          tokens[0...-1].each do |token|
            expect(token.line).to be >= 1
            expect(token.column).to be >= 1
          end
        end
      end
    end
  end
end