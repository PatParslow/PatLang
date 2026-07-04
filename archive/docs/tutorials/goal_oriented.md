# Goal-Oriented Programming in Patlang

Goal-oriented programming in Patlang lets you define goals and let the system resolve them. This paradigm is useful for expressing intent and letting the runtime determine how to achieve it.

## Concepts

- **Goals:** Desired outcomes or states, defined as named constructs.
- **Goal Resolution:** The system finds a way to achieve the goal, possibly using recursion or rules.
- **Declarative Style:** Focus on what you want, not how to do it.

## Syntax Overview

- Goal definition:
  ```patlang
  goal reach_target(x) {
    if x == 0 {
      print("Target reached!")
    } else {
      reach_target(x - 1)
    }
  }
  ```
- Goal invocation:
  ```patlang
  reach_target(3)
  ```

## Example: Recursive Goal

```patlang
goal countdown(n) {
  if n == 0 {
    print("Done!")
  } else {
    print(n)
    countdown(n - 1)
  }
}

countdown(5)
```

This code prints numbers from 5 down to 1, then "Done!".

## Example: Goal with Multiple Strategies

```patlang
goal solve(x) {
  if x > 10 {
    print("Large problem, using advanced strategy")
    // ... advanced logic ...
  } else {
    print("Simple problem, using basic strategy")
    // ... basic logic ...
  }
}

solve(3)
solve(20)
```

## Running the Example

Save the code to `goal_oriented_example.patlang` and run:

```sh
patlang run goal_oriented_example.patlang
```

## Tips

- Use goals to express intent, not just procedures.
- Combine with logic rules for powerful declarative solutions.
- Document the purpose of each goal for clarity.

## Next Steps

Explore logic programming in Patlang to build knowledge-based systems.