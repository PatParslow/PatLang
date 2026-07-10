# PatLang Standard Library - Collections Module
# Collection manipulation functions
# Implemented in PatLang with foreign primitives

import "core.pat"

# Higher-order function helpers
make a function called apply1 {
  takes: fn, arg
}

make a function called apply2 {
  takes: fn, arg1, arg2
}

# Map - apply function to each element
make a function called map {
  takes: items, fn
}

# Filter - keep elements that satisfy predicate
make a function called filter {
  takes: items, pred
}

# Reduce/fold - combine elements using binary function
make a function called reduce {
  takes: items, init, fn
}

# Reduce with no initial value
make a function called reduce1 {
  takes: items, fn
}

# Find first element matching predicate
make a function called find {
  takes: items, pred
}

# Find index of first matching element
make a function called find_index {
  takes: items, pred
}

# Check if any element matches predicate
make a function called any {
  takes: items, pred
}

# Check if all elements match predicate
make a function called all {
  takes: items, pred
}

# Check if no elements match predicate
make a function called none {
  takes: items, pred
}

# Count elements
make a function called count {
  takes: items, pred_or_val
}

# Sort list
make a function called sort {
  takes: items
}

make a function called sort_by {
  takes: items, key_fn
}

# Reverse a list
make a function called reverse {
  takes: items
}

# Slice - get sublist (avoid 'end' keyword)
make a function called slice {
  takes: items, start, finish
}

# Take first n elements
make a function called take {
  takes: items, n
}

# Drop first n elements
make a function called drop {
  takes: items, n
}

# Flatten nested lists
make a function called flatten {
  takes: items
}

# Zip - combine multiple lists
make a function called zip {
  takes: lists
}

# Remove duplicates
make a function called uniq {
  takes: items
}

# Group elements by key function
make a function called group_by {
  takes: items, key_fn
}

# Partition - split list by predicate
make a function called partition {
  takes: items, pred
}

# Chunk - split list into chunks of size n
make a function called chunk {
  takes: items, sz
}