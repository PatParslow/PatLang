require_relative '../helpers/test_helper'

class TestLoopCoverageBranches < Minitest::Test
  def setup
    # Setup for loop coverage testing
  end

  def test_while_loop_branches
    # Test while loop entry vs skip branches
    counter = 0
    while counter < 3
      counter += 1
    end
    assert_equal 3, counter, "Should execute while loop"
    
    # Test while loop that doesn't execute
    flag = false
    iterations = 0
    while flag
      iterations += 1
    end
    assert_equal 0, iterations, "Should skip while loop"
  end

  def test_until_loop_branches
    # Test until loop branches
    counter = 0
    until counter >= 3
      counter += 1
    end
    assert_equal 3, counter, "Should execute until loop"
  end

  def test_for_loop_branches
    # Test for loop branches with different collections
    collections = [
      [],           # empty collection
      [1],          # single item
      [1, 2, 3],    # multiple items
      {}            # empty hash
    ]
    
    collections.each do |collection|
      result = process_collection_loop(collection)
      assert_not_nil result, "Should handle collection: #{collection.inspect}"
    end
  end

  def test_iterator_branches
    # Test iterator method branches
    [[], [1], [1, 2, 3]].each do |array|
      result = array.map { |x| x * 2 }
      expected_length = array.length
      assert_equal expected_length, result.length, "Iterator should process all items"
    end
  end

  def test_break_and_next_branches
    # Test break and next in loops
    result = []
    (1..10).each do |i|
      next if i.even?  # Skip even numbers
      break if i > 7   # Stop after 7
      result << i
    end
    assert_equal [1, 3, 5, 7], result, "Should handle break and next"
  end

  def test_nested_loop_branches
    # Test nested loop branches
    result = []
    (1..3).each do |i|
      (1..2).each do |j|
        result << [i, j]
      end
    end
    assert_equal 6, result.length, "Should execute nested loops"
  end

  private

  def process_collection_loop(collection)
    result = []
    if collection.respond_to?(:each)
      collection.each do |item|
        result << item
      end
    end
    result
  end
end
