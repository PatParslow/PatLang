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

      describe "goal-oriented programming" do
        describe "goal declaration" do
          it "declares a simple goal with requirements and achievement conditions" do
            source = <<~PAT
              make a goal called build_app {
                requires: source_code, dependencies
                achieved when: executable_exists, tests_pass
                runs: {
                  compile(source_code)
                  run_tests()
                }
              }
            PAT

            eval_source(source)
            
            # Goal should be stored in environment
            # The declaration returns nil (like function declarations)
          end

          it "declares goal with empty body" do
            source = <<~PAT
              make a goal called simple_goal {
                requires: nothing
                achieved when: condition
              }
            PAT

            expect { eval_source(source) }.not_to raise_error
          end
        end

        describe "goal activation" do
          it "activates a declared goal with context" do
            source = <<~PAT
              make a goal called build_project {
                requires: source_path
                achieved when: true
                runs: { source_path }
              }
              
              ctx is { source_path: "src/" }
              activate build_project with ctx
            PAT

            # Should execute the goal
            result = eval_source(source)
            expect(result).to eq("src/")
          end

          it "activates a goal without context" do
            source = <<~PAT
              make a goal called hello {
                achieved when: true
                runs: { "Hello, World!" }
              }
              
              activate hello
            PAT

            result = eval_source(source)
            expect(result).to eq("Hello, World!")
          end

          it "errors on activating undefined goal" do
            source = <<~PAT
              activate undefined_goal
            PAT

            expect { eval_source(source) }.to raise_error(EvaluatorError, /not found/)
          end
        end

        describe "goal dependencies" do
          it "executes prerequisite goals first" do
            source = <<~PAT
              make a goal called compile {
                achieved when: object_files_exist
                runs: { compile_sources() }
              }
              
              make a goal called link {
                requires: object_files
                achieved when: executable_exists
                runs: { link_objects() }
              }
              
              make a goal called build {
                requires: compile, link
                achieved when: executable_ready
                runs: { package() }
              }
              
              activate build
            PAT

            # Should execute compile, then link, then build
            # based on dependency resolution
          end
        end

        describe "goal with preconditions" do
          it "fails if preconditions not met" do
            source = <<~PAT
              make a goal called deploy {
                requires: staging_success
                achieved when: deployed
                runs: { deploy_to_prod() }
              }
              
              # staging_success is not provided
              ctx is { staging_success: false }
              activate deploy with ctx
            PAT

            expect { eval_source(source) }.to raise_error(EvaluatorError, /requirement.*staging.*not satisfied/)
          end
        end
      end
    end
  end
end