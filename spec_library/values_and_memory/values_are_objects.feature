@language
Feature: every value is an object of a class, and answers methods through it (spec 1.1, 1.2)

  Scenario: type_of names the class of every kind of value
    Given the values 7, 2^70, 1.5, 6/4, true, the unit value print returns, "hi", [1, 2], a closure, sb_new(), vec_new(), bool_array_new(3) and logic_store_new()
    When type_of is applied to each
    Then the results are int, bigint, float, rational, bool, unit, string, list, closure, string_builder, vec, bool_array, rule_store

  Scenario: new returns the object, of the class it names
    Given w = new("Widget", "w1")
    When type_of(w) is read
    Then it is Widget

  Scenario: a value keeps its class however it is passed around
    Given the value 1.5 stored in a list, passed to a function, returned, and read back
    When type_of is applied to what was read back
    Then it is float, and the value is 1.5

  Scenario: methods work on literals and on variables alike
    Given 3.to_s, 3.14.to_s, [1, 2, 3].length, and n.to_s where n is 42
    When each is evaluated
    Then they are "3", "3.14", 3 and "42"

  Scenario: an object's name finds the same field as the object does
    Given an object named a1 with a field, and a string holding that name
    When a program reads and assigns the field through the string
    Then it sees the same field the object has, and the string still answers length

  Scenario: a class declared after 400 others is made and its inherited methods called as fast
    Given a class and its child declared first, the same two declared after 400 more classes, and a second class declared with the child's name
    When objects of each child are made and their inherited method called 2000 times
    Then each reads its own and its inherited field and method, the later costs no more than about four times the cycles of the first, and new finds the first class of the name, and a parent declared after its child gives the child's next object its field

  Scenario: an object's field is found as fast wherever it is among its fields
    Given an object given 512 fields one at a time, and a class whose objects start with 20
    When its 4th and 512th fields are read, one is set again, another added, and the 20 read
    Then each reads its value, a missing field reads as unit, a set keeps the field's place, and reading the 512th costs no more than about four times the cycles of the 4th

  Scenario: new takes a class and a name, and nothing more
    Given a call of new with further arguments after the name
    When the program runs
    Then it stops there, saying that a class declaration is how to inherit
