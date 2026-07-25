Feature: comparison operators == != < <= > >=

  Scenario: Equality and inequality
    Given 3 and 4
    When == and != are applied
    Then 3==3 is true, 3==4 is false, 3!=4 is true, 3!=3 is false

  Scenario: Ordering is strict for < and >, inclusive for <=/>=
    Given 3 and 4
    When <, <=, >, >= are applied
    Then 3<4 true, 4<3 false, 3<3 false; 3<=3 true; 4>3 true, 3>3 false; 3>=3 true

  Scenario: == does real value equality on strings, not reference identity
    Given two separately-constructed strings "abc"
    When == is applied
    Then the result is true

