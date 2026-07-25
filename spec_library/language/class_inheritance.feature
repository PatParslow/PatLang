Feature: class / inherits (single inheritance, field defaults)

  Scenario: A child class's own default overrides the parent's
    Given `class Animal { field legs = 4 }` and `class Person inherits Animal { field legs = 2 }`
    When new("Person", "p1") is created
    Then p.legs is 2, not 4 -- the more specific class wins

  Scenario: A field not redeclared by the child is still inherited
    Given Animal declares `field sound = "..."`, Person does not redeclare it
    When a Person instance reads .sound
    Then it is "...", inherited from Animal

  Scenario: An instance of the parent class is unaffected by the child's overrides
    Given the same two classes
    When new("Animal", "a1") is created directly
    Then a.legs is 4 (Animal's own default), not 2

