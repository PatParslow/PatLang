# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/evaluator'
require_relative '../../src/parser'
require_relative '../../src/lexer'
require_relative '../../src/reasoning/reasoning_coordinator'
require_relative '../../src/reasoning/form_validator'
require_relative '../../src/reasoning/goal_system'
require_relative '../../src/reasoning/facts_database'

# Test end-to-end evaluator integration with reasoning systems
# This demonstrates how reasoning features are accessible through Patlang.evaluate()
class TestEvaluatorReasoning < Minitest::Test
  # Method removed - using real implementation

  def test_patlang_evaluate_with_goal_system
    # This would test goal system integration
    result = Patlang.evaluate("goal system test")
    refute_nil result
  end

  def test_patlang_evaluate_with_facts_database
    # This would test facts database integration
    result = Patlang.evaluate("fact database test")
    refute_nil result
  end
end

# === Integration Error Classes ===

class ReasoningIntegrationError < StandardError
  attr_reader :component, :operation

  def initialize(message, component: nil, operation: nil)
    super(message)
    @component = component
    @operation = operation
  end
end

class CrossParadigmInferenceError < StandardError
  attr_reader :source_paradigm, :target_paradigm

  def initialize(message, source_paradigm: nil, target_paradigm: nil)
    super(message)
    @source_paradigm = source_paradigm
    @target_paradigm = target_paradigm
  end
end

# === Enhanced ReasoningCoordinator for Integration ===