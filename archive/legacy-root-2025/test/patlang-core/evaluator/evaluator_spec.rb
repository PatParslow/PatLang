# frozen_string_literal: true

require_relative '../../../test/test_helper'
require_relative '../../../patlang-core/lexer/lexer'
require_relative '../../../patlang-core/parser/parser'
require_relative '../../../patlang-core/ast/ast_nodes'
require_relative '../../../patlang-core/evaluator/evaluator'

module Patlang
  module Evaluator
    RSpec.describe Evaluator do
      def eval_source(source)
        lexer = Patlang::Lexer::Lexer.new(source)
        tokens = lexer.tokenize
        parser = Patlang::Parser::Parser.new(tokens)
        ast = parser.parse
        evaluator = Patlang::Evaluator::Evaluator.new
        evaluator.eval(ast)
      end

      describe "variable binding (IS)" do
        it "binds a simple value" do
          result = eval_source("x is 42")
          expect(result).to eq(42)
        end

        it "binds the result of an expression" do
          result = eval_source("x is 3 + 4")
          expect(result).to eq(7)
        end

        it "allows using bound variable in subsequent expressions" do
          result = eval_source("x is 42\nx")
          expect(result).to eq(42)
        end

        it "allows using bound variable in expressions" do
          result = eval_source("x is 5\ny is x + 3\ny")
          expect(result).to eq(8)
        end

        it "shadows outer bindings in nested scopes" do
          result = eval_source("x is 1\n{ x is 2 }\nx")
          expect(result).to eq(1)
        end
      end

      describe "variable mutation (BECOMES)" do
        it "mutates an existing binding" do
          result = eval_source("x is 5\nx becomes 10\nx")
          expect(result).to eq(10)
        end

        it "errors on mutating unbound variable" do
          expect { eval_source("x becomes 10") }.to raise_error(EvaluatorError, /not bound/)
        end
      end
    end
  end
end