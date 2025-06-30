# Event-Driven Programming in Patlang

Event-driven programming in Patlang uses events and handlers to react to changes or actions. This paradigm is useful for building interactive, modular, and responsive systems.

## Concepts

- **Events:** Named occurrences that can be triggered by code or the environment.
- **Handlers:** Functions that respond to events, encapsulating reaction logic.
- **Event Loop:** (If supported) Continuously waits for and dispatches events.

## Syntax Overview

- Event definition:
  ```patlang
  event onTick
  ```
- Handler definition:
  ```patlang
  handler onTick() {
    print("Tick event triggered!")
  }
  ```
- Triggering an event:
  ```patlang
  trigger onTick
  ```

## Example: Simple Event

```patlang
event onTick

handler onTick() {
  print("Tick event triggered!")
}

trigger onTick
```

This code defines an event, a handler, and triggers the event.

## Example: Multiple Events

```patlang
event onStart
event onStop

handler onStart() {
  print("Started!")
}

handler onStop() {
  print("Stopped!")
}

trigger onStart
trigger onStop
```

## Running the Example

Save the code to `event_driven_example.patlang` and run:

```sh
patlang run event_driven_example.patlang
```

## Tips

- Use events to decouple components and logic.
- Name events clearly to reflect their purpose.
- Combine with imperative or OOP code for complex workflows.

## Next Steps

Explore combining paradigms in Patlang for advanced, maintainable solutions.