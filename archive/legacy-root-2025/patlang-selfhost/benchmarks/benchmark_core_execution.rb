require 'benchmark'
require 'memory_profiler'

EXAMPLES = [
  '../../examples/arithmetic_demo.pat',
  '../../examples/control_flow_demo.pat',
  '../../examples/function_demo.pat',
  '../../examples/string_demo.pat'
]

INTERPRETER_PATH = '../src/interpreter.patlang'

def run_interpreter(example_path)
  # This assumes a CLI or host bridge exists to run the interpreter.
  # Replace with actual invocation if different.
  system("ruby ../../ruby-host/runtime/evaluator_old.rb #{INTERPRETER_PATH} #{example_path}")
end

results = []

EXAMPLES.each do |example|
  puts "Benchmarking: \#{example}"
  time = Benchmark.realtime do
    MemoryProfiler.report do
      run_interpreter(example)
    end.pretty_print(to_file: "memory_\#{File.basename(example)}.txt")
  end
  results << { file: example, time: time }
end

File.open('benchmark_results.md', 'w') do |f|
  f.puts "# Patlang Interpreter Core Execution Benchmark"
  f.puts "| Example | Time (s) |"
  f.puts "|---------|----------|"
  results.each do |r|
    f.puts "| \#{File.basename(r[:file])} | \#{'%.4f' % r[:time]} |"
  end
  f.puts "\nMemory profiles are saved as memory_*.txt."
end

puts "Benchmarking complete. Results in benchmark_results.md."