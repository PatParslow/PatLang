#!/usr/bin/env ruby

def prime?(n)
  return false if n < 2
  return true if n == 2
  return false if n.even?
  
  (3..Math.sqrt(n)).step(2) do |i|
    return false if n % i == 0
  end
  true
end

def count_primes_up_to(n)
  (0...n).count { |i| prime?(i) }
end

fact_count = 10000
prime_count = count_primes_up_to(fact_count)
expected_total = fact_count * 2 + prime_count

puts "fact_count: #{fact_count}"
puts "prime_count: #{prime_count}"
puts "expected_total: #{expected_total}"
puts "Current failing value: 16229"
puts "Difference: #{expected_total - 16229}"