Feature: classes with methods, inheritance and traits on named objects (GitHub #175)

  Real programs (patc1's own ObjCache and X64UnitLinker, the GOAP step classes,
  the synthesis demos) declare `class` blocks with methods and call them by name:
  `new("Dog", "d1")` creates a named object, `send("d1", "speak")` or `d1.speak()`
  calls a method, and inside a method `self` is the object's name, read with
  `get(self, "field")` or `self.field`.

  The real engine records the class as the object's `type`, registers each method
  as a closure, and resolves a call at run time in this order: the object's own
  class, then its traits (the LAST listed wins), then the parent class, repeating
  up the chain. Block-model does the same resolution at COMPILE time, because every
  class is declared in the program: each method becomes an ordinary function
  (`__cm_<Class>__<method>`), the class declaration also emits a `class_def` call so
  the real registry supplies field defaults and inheritance to `new`, and each
  method name called anywhere gets one dispatcher function that reads the object's
  `type` and calls the resolved method, falling back to the host `send` (so `"set"`
  and unknown methods behave as before). `send(recv, "m", ...)` and `recv.m(...)`
  are rewritten to call the dispatcher. (The real lowerer also treats a receiver that is an unbound bare
  identifier as the object's name, but the real engine skips such statements silently in practice, so that form is not part of the contract here.)

  Scenario: methods dispatch through own class, trait and parent, matching the real engine
    Given classes Animal (fields, speak, describe), Dog inheriting Animal with its own sound, Loud with a speak method, and Puppy inheriting Dog with `traits Loud`
    When objects of each class are created and their methods called with send and with a variable receiver
    Then it prints the same nine lines as pat --ir-run does for the identical source

  Member syntax on named objects. `obj.field` and `obj.field = value` used to
  take only the Box+Handler path, which needs the native heap and cannot even run
  under the interpreter. The receiver is now checked at run time: a string is a
  named object's name and is read with the host `get` and written with
  `send(name, "set", field, value)` (what the real lowerer emits); anything else
  is a Box object from `new("Class")` and takes the Phase 13 path unchanged. The
  read-only-parameter check moves into the Box path, since a name is a plain
  string and writing through `self` inside a method changes the registry, not the
  parameter.

  Scenario: field reads and writes on named objects, inside methods and outside, match the real engine
    Given a Counter class whose methods write self.n through send and through member assignment, and code that reads and writes the same object's fields through a variable holding its name
    When it runs through bm_lower_program/bi_run
    Then it prints the same eight lines as pat --ir-run does for the identical source

  Method-call syntax without a class. `obj.method(args)` is the host
  `send(obj, "method", args...)`. It is now lowered as an expression, and any
  expression statement that is not a plain call (a method call used for its
  effect, for instance) is evaluated and its value discarded. Both were rejected
  before ("an expression statement of kind 'MethodCall'"), which stopped the
  fuzz selftest, the router DSL demo and the parser harness.

  Scenario: method calls on ad hoc objects and built-in methods work as expressions and as statements
    Given an ad hoc named object with no class, a set method called for its effect and a to_s method called for its value
    When it runs through bm_lower_program/bi_run
    Then it prints the same three lines as pat --ir-run does for the identical source
