Feature: traits (composable mixins, last-listed wins on collision)

  Scenario: A colliding method name resolves to the LAST-listed trait
    Given `traits Nameable, Serializable`, both defining a "label" method
    When send(obj, "label") is called
    Then Serializable's label runs (listed last), not Nameable's

  Scenario: A non-colliding trait method is still composed in
    Given Serializable also defines "to_str", which Nameable does not
    When send(obj, "to_str") is called
    Then it runs correctly -- traits compose the UNION of methods, only colliding names follow last-wins

  Scenario: The class's own field declarations work unaffected
    Given Widget also declares `field kind = "widget"`
    When get(obj, "kind") is read
    Then it is "widget", regardless of the traits list

