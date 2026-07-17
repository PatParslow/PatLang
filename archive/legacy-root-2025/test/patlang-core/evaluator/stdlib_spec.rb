# frozen_string_literal: true

require_relative '../../../test/test_helper'
require_relative '../../../patlang-core/lexer/lexer'
require_relative '../../../patlang-core/parser/parser'
require_relative '../../../patlang-core/ast/ast_nodes'
require_relative '../../../patlang-core/evaluator/evaluator'

module Patlang
  module Evaluator
    RSpec.describe Evaluator do
      def eval_source(source, stdlib_modules = %w[core collections])
        lexer = Patlang::Lexer::Lexer.new(source)
        tokens = lexer.tokenize
        parser = Patlang::Parser::Parser.new(tokens)
        ast = parser.parse
        evaluator = Patlang::Evaluator::Evaluator.new(stdlib_modules)
        evaluator.eval(ast)
      end

      describe "standard library - core module" do
        it "provides type conversion functions" do
          source = <<~PAT
            to_string(42)
          PAT
          result = eval_source(source)
          expect(result).to eq("42")
        end

        it "provides to_number function" do
          source = <<~PAT
            to_number("3.14")
          PAT
          result = eval_source(source)
          expect(result).to eq(3.14)
        end

        it "provides to_boolean function" do
          source = <<~PAT
            to_boolean(1)
          PAT
          result = eval_source(source)
          expect(result).to be_truthy
        end

        it "provides type checking functions" do
          source = <<~PAT
            is_string?("hello")
          PAT
          result = eval_source(source)
          expect(result).to be_truthy
        end

        it "provides math functions" do
          source = <<~PAT
            add(2, 3)
          PAT
          result = eval_source(source)
          expect(result).to eq(5)
        end

        it "provides string functions" do
          source = <<~PAT
            string_length("hello")
          PAT
          result = eval_source(source)
          expect(result).to eq(5)
        end

        it "provides logical functions" do
          source = <<~PAT
            and(true, false)
          PAT
          result = eval_source(source)
          expect(result).to be_falsy
        end

        it "provides print function" do
          source = <<~PAT
            print("test")
          PAT
          # Should not raise error
          expect { eval_source(source) }.not_to raise_error
        end
      end

      describe "standard library - collections module" do
        it "provides map function" do
          source = <<~PAT
            double is {|x| x * 2}
            result is map([1, 2, 3], double)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq([2, 4, 6])
        end

        it "provides filter function" do
          source = <<~PAT
            pred is {|x| x > 2}
            result is filter([1, 2, 3, 4], pred)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq([3, 4])
        end

        it "provides reduce function" do
          source = <<~PAT
            sum is {|acc, x| acc + x}
            result is reduce([1, 2, 3, 4], 0, sum)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq(10)
        end

        it "provides find function" do
          source = <<~PAT
            pred is {|x| x > 1}
            result is find([1, 2, 3], pred)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq(2)
        end

        it "provides any? function" do
          source = <<~PAT
            pred is {|x| x > 2}
            result is any?([1, 2, 3], pred)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to be_truthy
        end

        it "provides all? function" do
          source = <<~PAT
            pred is {|x| x > 1}
            result is all?([2, 3, 4], pred)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to be_truthy
        end

        it "provides sort function" do
          source = <<~PAT
            sort([3, 1, 2])
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq([1, 2, 3])
        end

        it "provides uniq function" do
          source = <<~PAT
            uniq([1, 2, 2, 3])
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq([1, 2, 3])
        end

        it "provides range function" do
          source = <<~PAT
            range(1, 5)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq([1, 2, 3, 4, 5])
        end

        it "provides take function" do
          source = <<~PAT
            take([1, 2, 3, 4, 5], 3)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq([1, 2, 3])
        end

        it "provides chunk function" do
          source = <<~PAT
            chunk([1, 2, 3, 4, 5, 6], 2)
          PAT
          result = eval_source(source, %w[core collections])
          expect(result).to eq([[1, 2], [3, 4], [5, 6]])
        end
      end

      describe "standard library - feature flags" do
        it "loads only core by default" do
          evaluator = Patlang::Evaluator::Evaluator.new
          expect(evaluator.instance_variable_get(:@stdlib).module_names).to eq(['core'])
        end

        it "loads specified modules" do
          evaluator = Patlang::Evaluator::Evaluator.new(%w[core collections logic])
          expect(evaluator.instance_variable_get(:@stdlib).module_names).to include('core', 'collections', 'logic')
        end

        it "does not load collections functions when not enabled" do
          source = <<~PAT
            map([1, 2], {|x| x })
          PAT
          evaluator = Patlang::Evaluator::Evaluator.new(%w[core])
          expect { evaluator.eval(lexer_parse_eval(source)) }.to raise_error(EvaluatorError, /Variable 'map' is not bound/)
        end

        def lexer_parse_eval(source)
          lexer = Patlang::Lexer::Lexer.new(source)
          tokens = lexer.tokenize
          parser = Patlang::Parser::Parser.new(tokens)
          parser.parse
        end
      end

      describe "standard library - logic module" do
        it "provides assert function" do
          source = <<~PAT
            assert parent("john", "mary")
          PAT
          result = eval_source(source, %w[core logic])
          expect(result).to be_truthy
        end

        it "provides query function" do
          source = <<~PAT
            assert parent("john", "mary")
            query find_parents {
              parent("john", "mary")
            }
            end
          PAT
          result = eval_source(source, %w[core logic])
          expect(result).to be_truthy
        end

        it "provides variable creation" do
          source = <<~PAT
            var("X")
          PAT
          result = eval_source(source, %w[core logic])
          expect(result).to be_a(::TypeVariable)
        end

        it "provides term creation" do
          source = <<~PAT
            term("parent", "john", "mary")
          PAT
          result = eval_source(source, %w[core logic])
          expect(result).to be_a(::Term)
        end
      end

      describe "standard library - IO module" do
        it "provides format function" do
          source = <<~PAT
            format("Hello %s!", "world")
          PAT
          result = eval_source(source, %w[core io])
          expect(result).to eq("Hello world!")
        end

        it "provides json functions" do
          source = <<~PAT
            json_stringify({ "key": "value" })
          PAT
          result = eval_source(source, %w[core io])
          expect(result).to include("key")
        end
      end

      describe "standard library - goals module" do
        it "provides goal functions" do
          source = <<~PAT
            goal_system()
          PAT
          result = eval_source(source, %w[core goals])
          # Should return goal system instance
          expect(result).not_to be_nil
        end
      end
    end
  end
end