@language
Feature: values and objects with identity (spec 1.5)

  Scenario: list_set leaves the list it was given unchanged
    Given a = [1, 2, 3] and b = list_set(a, 0, 9)
    When both are read
    Then a is [1, 2, 3] and b is [9, 2, 3]

  Scenario: list_push leaves the list it was given unchanged, even with spare room
    Given a list a built by 10 list_push calls, then b = list_push(a, 99) and c = list_push(a, 77)
    When all three are read
    Then a has 10 elements, b ends in 99, and c ends in 77

  Scenario: equal lists built different ways are equal
    Given ["x", "y"] and list_push(list_push([], "x"), "y")
    When they are compared with ==
    Then the result is true

  Scenario: a change to an object is seen through every holder
    Given o = new("Widget", "w1"), p = o, and send(p, "set", "color", "red")
    When get(o, "color") is read
    Then it is "red"

  Scenario: two objects with the same contents are not equal
    Given two objects of class Point, each with x = 1 and y = 2
    When they are compared with ==
    Then the result is false, and an object compared with itself is true

  Scenario: a string builder is shared, not copied
    Given b = sb_new(), c = b, sb_push(c, "hi")
    When sb_str(b) is read
    Then it is "hi"

  Scenario: a vec is shared, not copied
    Given v = vec_new(), w = v, vec_push(w, 5)
    When vec_len(v) is read
    Then it is 1

  Scenario: a bool array keeps its identity when it grows
    Given a = bool_array_new(0), b = a, then 100 bool_array_push calls on a
    When bool_array_len(b) is read
    Then it is 100, and a == b is true
