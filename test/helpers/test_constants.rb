# Test constants to resolve NameError issues
require 'minitest/autorun'

module TestConstants
  # Define common test class constants
  TestEvaluatorBranchCoverage = Class.new(Minitest::Test)
  TestParserBranchCoverage = Class.new(Minitest::Test)
  TestLexerBranchCoverage = Class.new(Minitest::Test)
  TestASTNodesBranchCoverage = Class.new(Minitest::Test)
  TestObjectModelBranchCoverage = Class.new(Minitest::Test)
end

# Include constants globally for tests
include TestConstants
