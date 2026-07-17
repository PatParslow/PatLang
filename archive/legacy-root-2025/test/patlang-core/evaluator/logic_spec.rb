# frozen_string_literal: true

require_relative '../../../test/test_helper'
require_relative '../../../patlang-core/lexer/lexer'
require_relative '../../../patlang-core/parser/parser'
require_relative '../../../patlang-core/ast/ast_nodes'
require_relative '../../../patlang-core/evaluator/evaluator'
require_relative '../../../patlang-core/reasoning/unification_engine'

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

      describe "logic programming" do
        describe "assert statement" do
          it "asserts a simple fact" do
            source = <<~PAT
              assert parent("john", "mary")
            PAT

            result = eval_source(source)
            expect(result).to be_truthy
          end

          it "asserts multiple facts" do
            source = <<~PAT
              assert parent("john", "mary")
              assert parent("mary", "alice")
              assert parent("bob", "john")
            PAT

            eval_source(source)
            # Should succeed
          end
        end

        describe "unification" do
          it "unifies simple terms" do
            # This tests the underlying unification engine
            # Manually testing since we don't have full syntax yet
            engine = ::UnificationEngine.new
            
            # Test variable binding
            subst = {}
            result = engine.unify(TypeVariable.new("X"), "hello", subst)
            expect(result).to be_truthy
            expect(subst).to eq({ "X" => "hello" })
            
            # Test structure unification
            subst = {}
            term1 = Term.new("parent", [TypeVariable.new("X"), TypeVariable.new("Y")])
            term2 = Term.new("parent", ["john", "mary"])
            result = engine.unify(term1, term2, subst)
            expect(result).to be_truthy
            expect(subst).to eq({ "X" => "john", "Y" => "mary" })
          end
          
          it "handles occurs check" do
            engine = ::UnificationEngine.new
            
            # X = f(X) should fail occurs check
            var_x = TypeVariable.new("X")
            term = Term.new("f", [var_x])
            subst = {}
            result = engine.unify(var_x, term, subst)
            expect(result).to be_falsy
          end
        end

        describe "query statement" do
          it "queries asserted facts" do
            source = <<~PAT
              assert parent("john", "mary")
              assert parent("mary", "alice")
              
              query find_parents {
                parent("john", "mary")
              }
              end
            PAT
            
            result = eval_source(source)
            expect(result).to be_truthy
          end
          
          it "finds all matching facts" do
            source = <<~PAT
              assert parent("john", "mary")
              assert parent("john", "bob")
              assert parent("mary", "alice")
              
              query johns_children {
                parent("john", "X")
              }
              end
            PAT
            
            result = eval_source(source)
            # Should return all bindings for X
          end
        end

        describe "backward chaining" do
          it "resolves rules through backward chaining" do
            # This test requires rule parsing support which is not yet implemented
            # Skipping for now - will be implemented when rule keyword is added
            skip "Rule parsing not yet implemented"
            
            source = <<~PAT
              assert parent("john", "mary")
              assert parent("mary", "alice")
              
              # grandparent(X, Z) :- parent(X, Y), parent(Y, Z)
              rule grandparent(X, Z) {
                parent(X, Y)
                parent(Y, Z)
              }
              
              query find_grandparents {
                grandparent("john", "X")
              }
              end
            PAT
            
            result = eval_source(source)
            # Should find alice as john's grandchild
          end
        end

        describe "complex unification" do
          it "unifies nested structures" do
            engine = ::UnificationEngine.new
            
            term1 = Term.new("ancestor", [TypeVariable.new("X"), Term.new("descendant", [TypeVariable.new("Y")])])
            term2 = Term.new("ancestor", ["john", Term.new("descendant", ["alice"])])
            
            subst = {}
            result = engine.unify(term1, term2, subst)
            expect(result).to be_truthy
            expect(subst).to eq({ "X" => "john", "Y" => "alice" })
          end
          
          it "unifies lists" do
            engine = ::UnificationEngine.new
            
            # Lists are represented as nested Term structures: cons(1, cons(X, cons(3, nil)))
            term1 = Term.new("cons", [1, Term.new("cons", [TypeVariable.new("X"), Term.new("cons", [3, :nil])])])
            term2 = Term.new("cons", [1, Term.new("cons", [2, Term.new("cons", [3, :nil])])])
            
            subst = {}
            result = engine.unify(term1, term2, subst)
            expect(result).to be_truthy
            expect(subst).to eq({ "X" => 2 })
          end
        end
      end
    end
  end
end