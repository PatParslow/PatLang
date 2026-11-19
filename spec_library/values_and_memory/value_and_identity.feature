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

  Scenario: pushing onto a list nothing else holds does not copy all of it each time
    Given a loop of let out = list_push(out, e), where e reads out, at 20,000 and at 40,000 pushes
    When a program times them
    Then twice the pushes take no more than about three times as long

  Scenario: equal lists built different ways are equal
    Given ["x", "y"] and list_push(list_push([], "x"), "y")
    When they are compared with ==
    Then the result is true

  Scenario: a change to an object is seen through every holder
    Given o = new("Widget", "w1"), p = o, and send(p, "set", "color", "red")
    When get(o, "color") is read
    Then it is "red"

  Scenario: get tells a field holding false from a field that is not there
    Given o = new("Widget", "ga1") and send(o, "set", "off", false)
    When get(o, "off"), get(o, "missing"), get("ga1", "missing") and get(5, "missing") are read
    Then the first is false, and the other three are unit

  Scenario: each lookup says the same thing when nothing is there
    Given a list, a vec, a string, an object, an unset environment variable, a missing file, a missing virtual file and an unknown predicate
    When each is read where nothing is
    Then a list, a vec, a non-list or an object gives unit, a string gives "", getenv and read_file give "", file_exists gives false, vfs_exists gives false and query gives 0

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

  Scenario: a vec extended with a list keeps its order, and a list taken from it before keeps its value
    Given a vec holding 1, a list taken from it, then vec_extend with three elements, with an empty list, and with the vec's own contents, and a second vec extended twice with 10000 numbers
    When the vecs and the lists taken from them are read
    Then the first vec holds its elements twice in order, the lists taken earlier are unchanged, and the second vec holds 20000 numbers

  Scenario: a bytes is indexed and measured as a list is
    Given a bytes of three bytes, read by b[i] in range, past each end and with a string index, and measured with list_len before and after a push
    When each is read
    Then b[i] is the byte, unit wherever a list's index would give unit, and list_len is how many bytes it holds

  Scenario: bytes is a buffer of bytes with identity
    Given a bytes made, set, pushed to through a second holder, extended, sliced, compared, turned into text and lists and back, written to a file and read back, and pushed to a million times
    When each is read
    Then every byte is where it was put, a change through one holder is seen through the other, bytes_eq compares contents and == identity, the file holds the same bytes, and a million pushes take no more than about eight times as long as 250000

  Scenario: a bool array keeps its identity when it grows
    Given a = bool_array_new(0), b = a, then 100 bool_array_push calls on a
    When bool_array_len(b) is read
    Then it is 100, and a == b is true
