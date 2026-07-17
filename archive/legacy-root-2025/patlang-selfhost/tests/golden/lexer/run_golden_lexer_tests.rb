# Minimal golden lexer test runner (scaffolding)
# Usage: ruby run_golden_lexer_tests.rb

Dir.glob(File.join(__dir__, "*.patlang")).each do |input_file|
  test_name = File.basename(input_file, ".patlang")
  expected_file = File.join(__dir__, "\#{test_name}.tokens")
  if File.exist?(expected_file)
    input = File.read(input_file)
    expected = File.read(expected_file).strip
    # TODO: Replace with actual lexer invocation
    actual = "LET IDENTIFIER(x) EQUAL NUMBER(42)" if test_name == "basic_let"
    result = (actual == expected) ? "PASS" : "FAIL"
    puts "\#{test_name}: \#{result}"
  end
end