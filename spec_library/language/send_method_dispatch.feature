Feature: send (real user-defined method dispatch)

  Scenario: A child class's own method overrides the parent's
    Given Animal defines speak() returning get(self,"sound"); Person (inherits Animal) defines its OWN speak() returning a job-based message
    When send(person_instance, "speak") is called
    Then Person's own speak() runs -- "hi, my job is unemployed"

  Scenario: An instance with no override uses the parent's method
    Given the same two classes
    When send(animal_instance, "speak") is called
    Then Animal's own speak() runs, returning its sound field's value

  Note: this is a REAL closure call (the interpreter resolves the
  method by walking own-class then parent chain and invokes it
  directly), distinct from send(obj, "set", field, val) -- the ONLY
  hard-coded verb host_send itself understands; any other method name
  is resolved by the interpreter's own dispatch, not a host function.

