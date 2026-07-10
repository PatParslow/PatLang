# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../../patlang-core', __dir__))

require 'rspec'
require 'pathname'

# Test helper configuration
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  
  Kernel.srand config.seed
end

# Custom matchers
RSpec::Matchers.define :tokenize_to do |expected_tokens|
  match do |lexer|
    @actual = lexer.tokenize
    @actual[0...-1].map { |t| [t.type, t.value] } == expected_tokens
  end
  
  failure_message do |lexer|
    "expected tokens: #{expected_tokens}\nactual: #{@actual[0...-1].map { |t| [t.type, t.value] }}"
  end
end

# Parse helper for integration tests
module ParseHelpers
  def parse(source, expectations = [])
    # Will be implemented when parser is ready
  end
  
  def eval_patlang(source)
    # Will be implemented when evaluator is ready
  end
end

RSpec.configure do |config|
  config.include ParseHelpers
end