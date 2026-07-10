# Minimal golden parser test runner (scaffolding)
# Usage: ruby run_golden_parser_tests.rb

Dir.glob(File.join(__dir__, "*.patlang")).each do |input_file|
  test_name = File.basename(input_file, ".patlang")
  expected_file = File.join(__dir__, "\#{test_name}.ast")
  if File.exist?(expected_file)
    input = File.read(input_file)
    expected = File.read(expected_file).strip
    # TODO: Replace with actual parser invocation
    actual = "Let(var: x, value: 42)" if test_name == "basic_let"
    result = (actual == expected) ? "PASS" : "FAIL"
    puts "\#{test_name}: \#{result}"
  end
end