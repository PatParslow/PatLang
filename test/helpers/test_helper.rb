require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_group 'Source', 'src'
end

require 'minitest/autorun'
require_relative '../../src/parse_error'