# frozen_string_literal: true

require_relative '../../../test/test_helper'
require_relative '../../../patlang-core/lexer/lexer'
require_relative '../../../patlang-core/parser/parser'
require_relative '../../../patlang-core/ast/ast_nodes'

module Patlang
  module Parser
    RSpec.describe Parser do
      def parse_source(source, expectations: nil)
        lexer = Lexer::Lexer.new(source)
        tokens = lexer.tokenize(expectations: expectations || [])
        parser = Parser.new(tokens)
        parser.parse
      end
      
      describe "basic literals" do
        it "parses integers" do
          ast = parse_source("42")
          expect(ast.statements.first).to be_a(AST::ExpressionStatementNode)
          expr = ast.statements.first.expression
          expect(expr).to be_a(AST::IntegerLiteralNode)
          expect(expr.value).to eq(42)
        end
        
        it "parses floats" do
          ast = parse_source("3.14")
          expr = ast.statements.first.expression
          expect(expr).to be_a(AST::FloatLiteralNode)
          expect(expr.value).to eq(3.14)
        end
        
        it "parses strings" do
          ast = parse_source('"hello"')
          expr = ast.statements.first.expression
          expect(expr).to be_a(AST::StringLiteralNode)
          expect(expr.value).to eq("hello")
        end
        
        it "parses booleans" do
          ast = parse_source("true")
          expect(ast.statements.first.expression).to be_a(AST::BooleanLiteralNode)
          expect(ast.statements.first.expression.value).to be true
        end
        
        it "parses nil" do
          ast = parse_source("nil")
          expect(ast.statements.first.expression).to be_a(AST::NilLiteralNode)
        end
      end
      
      describe "identifiers and variables" do
        it "parses identifier" do
          ast = parse_source("x")
          expect(ast.statements.first.expression).to be_a(AST::IdentifierNode)
          expect(ast.statements.first.expression.name).to eq("x")
        end
      end
      
      describe "variable binding (IS)" do
        it "parses simple binding" do
          ast = parse_source("x is 42", expectations: [
            :IDENTIFIER, :IS_KEYWORD, :INTEGER_LITERAL
          ])
          stmt = ast.statements.first
          expect(stmt).to be_a(AST::AssignmentNode)
          expect(stmt.name).to eq("x")
          expect(stmt.value).to be_a(AST::IntegerLiteralNode)
        end
        
        it "parses binding with expression" do
          ast = parse_source("x is 3 + 4", expectations: [
            :IDENTIFIER, :IS_KEYWORD, :INTEGER_LITERAL, :PLUS, :INTEGER_LITERAL
          ])
          stmt = ast.statements.first
          expect(stmt).to be_a(AST::AssignmentNode)
          expect(stmt.name).to eq("x")
          expect(stmt.value).to be_a(AST::BinaryOpNode)
        end
      end
      
      describe "variable mutation (BECOMES)" do
        it "parses mutation" do
          ast = parse_source("x becomes 43", expectations: [
            :IDENTIFIER, :BECOMES_KEYWORD, :INTEGER_LITERAL
          ])
          stmt = ast.statements.first
          expect(stmt).to be_a(AST::MutationNode)
          expect(stmt.name).to eq("x")
        end
      end
      
      describe "function calls" do
        it "parses zero-argument call" do
          ast = parse_source("foo()")
          call = ast.statements.first.expression
          expect(call).to be_a(AST::CallNode)
          expect(call.arguments).to be_empty
        end
        
        it "parses called with arguments" do
          ast = parse_source("add(1, 2)")
          call = ast.statements.first.expression
          expect(call).to be_a(AST::CallNode)
          expect(call.arguments.length).to eq(2)
        end
      end
      
      describe "binary operations" do
        it "parses addition" do
          ast = parse_source("1 + 2")
          binop = ast.statements.first.expression
          expect(binop).to be_a(AST::BinaryOpNode)
          expect(binop.operator).to eq("+")
        end
        
        it "parses precedence correctly" do
          ast = parse_source("1 + 2 * 3")
          binop = ast.statements.first.expression
          expect(binop).to be_a(AST::BinaryOpNode)
          expect(binop.operator).to eq("+")
          expect(binop.right).to be_a(AST::BinaryOpNode)
          expect(binop.right.operator).to eq("*")
        end
        
        it "parens override precedence" do
          ast = parse_source("(1 + 2) * 3")
          binop = ast.statements.first.expression
          expect(binop).to be_a(AST::BinaryOpNode)
          expect(binop.operator).to eq("*")
          expect(binop.left).to be_a(AST::ParenExpressionNode)
        end
      end
      
      describe "unary operations" do
        it "parses negation" do
          ast = parse_source("-42")
          unop = ast.statements.first.expression
          expect(unop).to be_a(AST::UnaryOpNode)
          expect(unop.operator).to eq("-")
        end
        
        it "parses logical not" do
          ast = parse_source("not true")
          unop = ast.statements.first.expression
          expect(unop).to be_a(AST::UnaryOpNode)
          expect(unop.operator).to eq("not")
        end
      end
      
      describe "list literals" do
        it "parses empty list" do
          ast = parse_source("[]", expectations: [:LBRACKET, :RBRACKET])
          list = ast.statements.first.expression
          expect(list).to be_a(AST::ListLiteralNode)
          expect(list.elements).to be_empty
        end
        
        it "parses list with elements" do
          ast = parse_source("[1, 2, 3]")
          list = ast.statements.first.expression
          expect(list).to be_a(AST::ListLiteralNode)
          expect(list.elements.length).to eq(3)
        end
      end
      
      describe "parenthesized expressions" do
        it "parses parens" do
          ast = parse_source("(42)")
          paren = ast.statements.first.expression
          expect(paren).to be_a(AST::ParenExpressionNode)
          expect(paren.expression).to be_a(AST::IntegerLiteralNode)
        end
      end
      
      describe "lambda expressions" do
        it "parses simple lambda" do
          ast = parse_source("|x| x + 1", expectations: [
            :BLOCK_PARAM_START, :IDENTIFIER, :BLOCK_PARAM_END, :IDENTIFIER, :PLUS, :INTEGER_LITERAL
          ])
          lambda = ast.statements.first.expression
          expect(lambda).to be_a(AST::LambdaNode)
          expect(lambda.parameters.length).to eq(1)
          expect(lambda.parameters.first.name).to eq("x")
        end
        
        it "parses lambda with multiple params" do
          ast = parse_source("|a, b| a + b")
          lambda = ast.statements.first.expression
          expect(lambda.parameters.length).to eq(2)
        end
      end
      
      describe "control flow - if" do
        it "parses simple if" do
          ast = parse_source("if x then y end")
          if_stmt = ast.statements.first
          expect(if_stmt).to be_a(AST::IfStatementNode)
          expect(if_stmt.condition).to be_a(AST::IdentifierNode)
        end
        
        it "parses if with else" do
          ast = parse_source("if x then y else z end")
          if_stmt = ast.statements.first
          expect(if_stmt.else_branch).not_to be_nil
        end
        
        it "parses elsif" do
          ast = parse_source("if x then y elsif z then w end")
          if_stmt = ast.statements.first
          expect(if_stmt.elsif_branches.length).to eq(1)
        end
      end
      
      describe "control flow - while" do
        it "parses while loop" do
          ast = parse_source("while x do y end")
          while_stmt = ast.statements.first
          expect(while_stmt).to be_a(AST::WhileStatementNode)
        end
      end
      
      describe "control flow - for" do
        it "parses for-in loop" do
          ast = parse_source("for x in items do y end")
          for_stmt = ast.statements.first
          expect(for_stmt).to be_a(AST::ForStatementNode)
          expect(for_stmt.variable).to eq("x")
        end
        
        it "parses for-range loop" do
          ast = parse_source("for i in range(1, 10) do y end")
          for_stmt = ast.statements.first
          expect(for_stmt.is_range).to be true
        end
      end
      
      describe "blocks" do
        it "parses brace block" do
          ast = parse_source("{ x is 42 }", expectations: [:BLOCK_START, :IDENTIFIER, :IS_KEYWORD, :INTEGER_LITERAL, :BLOCK_END])
          block = ast.statements.first.expression
          expect(block).to be_a(AST::BlockNode)
          expect(block.statements.length).to eq(1)
        end
      end
      
      describe "function declarations" do
        it "parses simple function" do
          source = <<~PAT
            make a function called add {
              takes: a, b
              returns: a + b
            }
          PAT
          
          ast = parse_source(source)
          decl = ast.statements.first
          expect(decl).to be_a(AST::FunctionDeclarationNode)
          expect(decl.name).to eq("add")
          expect(decl.parameters.length).to eq(2)
        end
      end
      
      describe "event handlers" do
        it "parses basic when handler" do
          source = <<~PAT
            when user:login { print "hello" }
          PAT
          
          ast = parse_source(source)
          handler = ast.statements.first
          expect(handler).to be_a(AST::EventHandlerNode)
          expect(handler.event_name).to eq("user")
          expect(handler.event_action).to eq(:login)
        end
        
        it "parses when without action" do
          source = <<~PAT
            when message { print message }
          PAT
          
          ast = parse_source(source)
          handler = ast.statements.first
          expect(handler).to be_a(AST::EventHandlerNode)
          expect(handler.event_name).to eq("message")
          expect(handler.event_action).to be_nil
        end
      end
      
      describe "activate statements" do
        it "parses activate without args" do
          ast = parse_source("activate my_goal")
          stmt = ast.statements.first
          expect(stmt).to be_a(AST::ActivateStatementNode)
          expect(stmt.goal_name).to eq("my_goal")
        end
        
        it "parses activate with args" do
          ast = parse_source("activate foo with bar")
          stmt = ast.statements.first
          expect(stmt.arguments).not_to be_nil
        end
      end
      
      describe "assert statements" do
        it "parses assert" do
          ast = parse_source("assert parent(alice, bob)")
          stmt = ast.statements.first
          expect(stmt).to be_a(AST::AssertStatementNode)
          expect(stmt.predicate).to eq("parent")
        end
      end
      
      describe "return statements" do
        it "parses return with value" do
          ast = parse_source("return 42")
          stmt = ast.statements.first
          expect(stmt).to be_a(AST::ReturnStatementNode)
          expect(stmt.value).to be_a(AST::IntegerLiteralNode)
        end
        
        it "parses return without value" do
          ast = parse_source("return")
          stmt = ast.statements.first
          expect(stmt).to be_a(AST::ReturnStatementNode)
          expect(stmt.value).to be_nil
        end
      end
    end
  end
end