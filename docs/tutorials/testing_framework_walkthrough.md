# Walkthrough: Designing a Testing Framework in Patlang

This walkthrough demonstrates how to design a simple, extensible testing framework in Patlang, leveraging multiple paradigms.

---

## 1. Requirements

- Define and group test cases.
- Run tests and report results.
- Support assertions and custom test logic.
- Extensible for future features (e.g., setup/teardown, parameterized tests).
- **Goal-Oriented:** Allow users to specify high-level testing goals (e.g., "all tests pass", "coverage above 90%").
- **Logic Programming:** Enable rule-based test selection, dynamic test dependencies, and advanced reporting.
- **Programming by Contract:** Use contracts to define setup/teardown and enforce pre/post-conditions.

---

## 2. High-Level Design

- **OOP:** Use classes for test suites and test cases.
- **Imperative:** Control test execution flow.
- **Functional:** Pass test logic as functions.
- **Event-Driven:** Emit events for test start, pass, fail.
- **Goal-Oriented:** Define goals such as "achieve full coverage" or "run all critical tests".
- **Logic:** Use facts/rules to select tests, express dependencies, or generate reports.
- **Contract:** Use preconditions, postconditions, and invariants for setup/teardown.

---

## 3. Core Components

### TestCase Class with Contract Support

```patlang
class TestCase {
  var name
  var test_fn
  var setup_fn
  var teardown_fn
  var contract

  method run() {
    if contract and not contract.pre() {
      emit test_failed(self.name, "Precondition failed")
      return
    }
    if setup_fn { setup_fn() }
    try {
      self.test_fn()
      if contract and not contract.post() {
        emit test_failed(self.name, "Postcondition failed")
      } else {
        emit test_passed(self.name)
      }
    } catch (e) {
      emit test_failed(self.name, e)
    }
    if teardown_fn { teardown_fn() }
  }
}
```

### Contract Class

```patlang
class Contract {
  var pre
  var post

  method pre() {
    if pre { return pre() } else { return true }
  }
  method post() {
    if post { return post() } else { return true }
  }
}
```

### TestSuite Class

```patlang
class TestSuite {
  var cases = []

  method add_case(tc) {
    cases = cases + [tc]
  }

  method run_all() {
    for tc in cases {
      tc.run()
    }
  }
}
```

### Assertion Helpers

```patlang
fun assert_eq(a, b) {
  if a != b {
    throw("Assertion failed: " + a + " != " + b)
  }
}
```

---

## 4. Event Handlers

```patlang
event test_passed(name)
event test_failed(name, error)

handler test_passed(name) {
  print("PASS: " + name)
}

handler test_failed(name, error) {
  print("FAIL: " + name + " (" + error + ")")
}
```

---

## 5. Goal-Oriented Extensions

### Defining Testing Goals

```patlang
goal all_tests_passed(suite) {
  suite.run_all()
  if no_failures() {
    print("All tests passed!")
  } else {
    print("Some tests failed.")
  }
}
```

### Example Usage

```patlang
all_tests_passed(suite)
```

### Advanced Goal: Achieve Coverage

```patlang
goal achieve_coverage(suite, percent) {
  suite.run_all()
  if coverage() >= percent {
    print("Coverage goal met!")
  } else {
    print("Coverage goal not met.")
  }
}
```

---

## 6. Logic Programming Enhancements

### Rule-Based Test Selection

```patlang
fact test_case(name, critical)
fact test_case(name, optional)

rule should_run(name) {
  test_case(name, critical)
}
```

### Dynamic Dependencies

```patlang
fact depends_on(testA, testB)

rule can_run(testA) {
  not depends_on(testA, testB) or test_passed(testB)
}
```

### Example: Running Only Critical Tests

```patlang
for tc in suite.cases {
  if should_run(tc.name) {
    tc.run()
  }
}
```

---

## 7. Example Usage with Contract and Setup/Teardown

```patlang
fun setup_db() { print("Setting up DB") }
fun teardown_db() { print("Tearing down DB") }
fun precondition() { return true }
fun postcondition() { return true }

var contract = Contract(precondition, postcondition)

fun test_addition() {
  assert_eq(2 + 2, 4)
}

var tc = TestCase("Addition", test_addition, setup_db, teardown_db, contract)
var suite = TestSuite()
suite.add_case(tc)
all_tests_passed(suite)
```

---

## 8. Extending the Framework

- Add more contract types (invariants, exception guarantees).
- Use contracts for resource management and cleanup.
- Integrate with logic or goal-oriented paradigms for advanced test selection and reporting.
- Use logic rules to generate test coverage reports or enforce test dependencies.

---

## 9. Summary

This framework demonstrates Patlang's multi-paradigm strengths: OOP for structure, functional for test logic, imperative for control, event-driven for reporting, goal-oriented for high-level intent, logic programming for advanced selection and reasoning, and programming by contract for robust setup/teardown and correctness guarantees.