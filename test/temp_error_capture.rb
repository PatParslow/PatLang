require 'timeout'

output_file = './temp_test_output.txt'

begin
  Timeout::timeout(30) do
    # Redirect both stdout and stderr to capture all output
    original_stdout = $stdout
    original_stderr = $stderr
    
    begin
      File.open(output_file, 'w') do |f|
        $stdout = f
        $stderr = f
        
        # Set up the load path
        $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))
        $LOAD_PATH.unshift(File.dirname(__FILE__))
        
        load './infrastructure/test_type_constraint_parser.rb'
      end
    rescue => e
      File.open(output_file, 'a') do |f|
        f.puts "ERROR: #{e.class}: #{e.message}"
        f.puts "BACKTRACE:"
        e.backtrace&.each { |line| f.puts "  #{line}" }
      end
      exit 1
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  
  # If we get here, the test completed without error
  File.write(output_file, "") unless File.exist?(output_file)
  exit 0
  
rescue Timeout::Error
  File.open(output_file, 'w') do |f|
    f.puts "TIMEOUT: Test exceeded 30 seconds"
  end
  exit 124
end
