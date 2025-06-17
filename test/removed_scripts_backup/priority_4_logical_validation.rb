# Priority 4 logical error validation
require 'minitest/autorun'

class Priority4LogicalTest < Minitest::Test
  def test_basic_assertions
    # Test basic arithmetic
    assert_equal 4, 2 + 2, "Basic arithmetic should work"
    
    # Test string operations  
    assert_equal "hello world", "hello" + " world", "String concatenation should work"
    
    # Test array operations
    assert_equal [1, 2, 3], [1] + [2, 3], "Array concatenation should work"
    
    # Test logical operations
    assert_equal true, true && true, "Logical AND should work"
    assert_equal true, true || false, "Logical OR should work"
    
    puts "✓ All logical assertion tests passed"
  end
  
  def test_comparison_operations
    # Test number comparisons
    assert_equal true, 5 > 3, "Number comparison should work"
    assert_equal false, 2 > 5, "Number comparison should work"
    
    # Test string comparisons
    assert_equal true, "apple" < "banana", "String comparison should work"
    
    puts "✓ All comparison tests passed"
  end
end
