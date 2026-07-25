Feature: obj.prop = value (member-assignment sugar)

  Scenario: Dot-assignment writes the same store dot-read and get() both read from
    Given `o.color = "blue"` on an object with no color field previously set
    When o.color and get(o, "color") are both read afterward
    Then both return "blue" -- confirming dot-assignment, dot-read, and get() all agree on the same underlying field store

