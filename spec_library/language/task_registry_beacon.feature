Feature: task_registry (presence beacon, built on queue.patlang)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). Each program removes its task's
  topic first and last: the beacon is real files, as the queue is.

  Scenario: An announcement is readable back immediately, and discover_all finds it
    Given the program
      """
      include "{lib}/task_registry.patlang"
      let t = "spec_scratch_beacon_task"
      queue_remove_topic(tr_topic_for(t))
      tr_announce(t, "does spec work")
      print(tr_read_one(t)[1])
      let all = tr_discover_all(60000)
      let found = false
      let i = 0
      while i < list_len(all) do
        if all[i][0] == t then
          let found = true
        end
        let i = i + 1
      end
      print(found)
      queue_remove_topic(tr_topic_for(t))
      """
    When it runs interpreted and compiled
    Then both print
      """
      does spec work
      true
      """

  Scenario: re-announcing OVERWRITES, never accumulates
    Given the program
      """
      include "{lib}/task_registry.patlang"
      let t = "spec_scratch_beacon_task2"
      queue_remove_topic(tr_topic_for(t))
      tr_announce(t, "does spec work")
      tr_announce(t, "a different description")
      print(list_len(q_read(tr_topic_for(t))))
      print(tr_read_one(t)[1])
      queue_remove_topic(tr_topic_for(t))
      """
    When it runs interpreted and compiled
    Then both print
      """
      1
      a different description
      """
