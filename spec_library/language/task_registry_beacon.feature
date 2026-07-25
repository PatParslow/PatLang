Feature: task_registry (presence beacon, built on queue.patlang)

  Scenario: An announcement is readable back immediately
    Given tr_announce("spec_scratch_beacon_task", "does spec work")
    When tr_read_one is called for that task
    Then it returns the announced description

  Scenario: discover_all finds a fresh announcement within its age window
    Given the same recent announcement
    When tr_discover_all(60000) is called
    Then the task appears in the results

  Scenario: re-announcing OVERWRITES, never accumulates
    Given a second tr_announce call for the same task, with a different description
    When the underlying row count is checked via an ensure guard
    Then exactly 1 row exists, not 2 -- confirming this beacon keeps only its LATEST state, unlike queue_publish's own accumulating log

