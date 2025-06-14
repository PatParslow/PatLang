# we want to determine the number of lines of code in src, and separately in test
# and we want to determine the number of words in documentation in docs
#

# use wc -l to count lines
# use wc -w to count words
#

puts "source code lines: "
puts `wc -l src/*/*.rb`

puts "test code lines: "
puts `wc -l test/*/*.rb`

puts "documentation words: "
puts `wc -w docs/*/*.md`
