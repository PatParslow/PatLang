# Combining Paradigms in Patlang

Patlang allows you to combine multiple paradigms for powerful and flexible solutions. This section demonstrates how to mix OOP, functional, goal-oriented, logic, and event-driven styles.

## Why Combine Paradigms?

- **Expressiveness:** Use the best paradigm for each part of a problem.
- **Maintainability:** Separate concerns and encapsulate logic.
- **Scalability:** Build complex systems by composing simple parts.

## Example 1: OOP + Functional

```patlang
class ListOps {
  method map(f, list) {
    if list == [] {
      []
    } else {
      [f(list[0])] + self.map(f, list[1:])
    }
  }
}

var ops = ListOps()
print(ops.map(x => x * 2, [1, 2, 3]))
```

This example uses a class to encapsulate a functional `map` method.

## Example 2: Goal-Oriented + Logic

```patlang
fact parent(alice, bob)
fact parent(bob, carol)

goal find_grandchild(X) {
  query parent(X, Y)
  query parent(Y, Z)
  print("Grandchild: " + Z)
}

find_grandchild(alice)
```

This example combines logic facts and queries with a goal to find a grandchild.

## Example 3: Event-Driven + Imperative

```patlang
event onStart

handler onStart() {
  var x = 0
  while x < 3 {
    print("Event loop: " + x)
    x = x + 1
  }
}

trigger onStart
```

This example uses an event to trigger an imperative loop.

## Running the Examples

Save each code block to its own `.patlang` file and run with:

```sh
patlang run your_example.patlang
```

## Tips

- Start with a single paradigm, then add others as needed.
- Document how and why paradigms are combined.
- Test each part in isolation before integrating.

## Next Steps

Read about advanced patterns and best practices for multi-paradigm Patlang code.