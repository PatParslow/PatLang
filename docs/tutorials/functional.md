# Functional Programming in Patlang

Functional programming in Patlang enables first-class functions, immutability, and recursion. This paradigm is ideal for data transformation, pure computation, and concise code.

## Concepts

- **First-Class Functions:** Functions can be assigned to variables, passed as arguments, and returned from other functions.
- **Immutability:** Prefer not to mutate data; use new values instead.
- **Recursion:** Functions can call themselves for iteration.
- **Pure Functions:** Functions with no side effects.

## Syntax Overview

- To define a function, use the "make a function called..." syntax:

  > make a function called `double` that takes `x` and returns `x * 2`

  ```patlang
  make a function called double takes: x {
    return x * 2
  }
  ```
- To define a higher-order function, use:

  > make a function called `map` that takes `f` and `list`, and returns an empty list if `list` is empty, otherwise returns `[f(list[0])]` plus `map(f, list[1:])`

  ```patlang
  make a function called map takes: f, list {
    if list.is_empty() then
      return make_empty_list()
    else
      return make_list(call f with list.head(), call map with f, list.tail())
    end
  }
  ```
- To define an anonymous function, use:

  > make an anonymous function that takes `x` and returns `x * 2`

  ```patlang
  x => x * 2
  ```

## Example: Mapping a Function

```patlang
make a function called double that takes x and returns x * 2

make a function called map that takes f and list {
  if list == [] {
    return []
  } else {
    return [f(list[0])] + map(f, list[1:])
  }
}

print(map(double, [1, 2, 3, 4]))
```

This code defines a `double` function and a `map` function, then applies `double` to a list.

## Example: Filtering a List

```patlang
make a function called is_even takes: x {
  return x % 2 == 0
}

# Test even number checking
test_number = 4
result = call is_even with test_number
print("Is 4 even?")
print(result)

# Working with list filtering concept
test_list = call make_list with 2, call make_empty_list
is_head_even = call is_even with test_list.head().value
print("Is head of [2] even?")
print(is_head_even)
```

## Running the Example

Save the code to `functional_example.patlang` and run:

```sh
patlang run functional_example.patlang
```

## Tips

- Write pure functions for easier testing and reuse.
- Use recursion for iteration instead of loops.
- Combine with OOP for powerful abstractions.

## Next Steps

Explore event-driven programming in Patlang to react to changes and build interactive systems.