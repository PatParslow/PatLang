Feature: new / send("set",...) / get (ad hoc objects, no class declared)

  Scenario: An ad hoc object gets implicit type/name fields for free
    Given `new("Widget", "w1")`, with no `class Widget {...}` ever declared
    When get(obj, "type") and get(obj, "name") are read
    Then they are "Widget" and "w1" respectively -- auto-populated by new() itself, not something the caller has to set

  Scenario: send("set",...) writes a field, get reads it back
    Given send(obj, "set", "color", "red")
    When get(obj, "color") is read
    Then it is "red"

