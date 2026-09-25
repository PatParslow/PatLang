Feature: object orientation, fields only (Phase 13 of the full-language expansion)

  Scoped deliberately, checked before writing code, not discovered as a gap
  afterward: this phase supports a class's declared FIELDS only --
  `new("ClassName")` constructs a real, refcounted object from its field
  defaults, and `obj.field` / `obj.field = value` read and write them.
  Methods, `inherits`, and `traits` were rejected here with a plain message
  naming which one; issue #175 lifted that restriction (see
  class_methods.feature: classes are expanded before lowering, methods compile
  to ordinary functions, and calls dispatch through a per-method dispatcher).
  This feature keeps its own scope, class fields on Box objects.

  An object here is represented as a refcounted Box (Phase 1/3) holding an
  ordinary Handler-shaped assoc-list (Phase 4) of field name/value pairs --
  not a new heap layout. This answers the plan's own flagged open
  question directly: does `mut` extend to field writes the same way it
  covers list mutation? Yes, exactly, because writing a field literally
  IS calling box_set on the object's own whole record -- the SAME
  refcount-checked mutate-in-place-vs-clone mechanism Phase 3 already
  proved, with no new mechanism built for objects specifically. When a
  field write clones (because the object was aliased), the block's own
  local variable holding the object is automatically re-pointed at the
  clone if it was a bare Var -- otherwise there is nothing to re-point.

  Scenario: field defaults are applied at construction
    Given a class with two fields and their own default expressions
    When an instance is constructed with no further arguments
    Then reading each field back returns its own declared default

  Scenario: a field write is visible on the next read, when the object is uniquely owned
    Given a freshly-constructed object referenced from exactly one place
    When one of its fields is written through a mut parameter
    Then reading that field back afterward returns the new value

  Scenario: a field write through an aliased mut reference clones, leaving the other alias untouched
    Given two live references to the same object, one of them mut
    When a field is written through the mut reference
    Then the mut reference's own local sees the new value while the other alias still sees the original

  Scenario: a class declaring inheritance, methods, or traits is accepted (issue #175)
    Given a class declaration that uses inherits, or declares a method, or declares traits
    When the program is lowered
    Then it lowers without error: inheritance, methods and traits are supported (issue #175)
