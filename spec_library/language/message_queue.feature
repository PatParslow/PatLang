Feature: message queue (queue_publish/consume/ack/pending, self_hosting/lib/queue.patlang)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). Each program removes its topic
  first and last: the queue is real files (.patlang_queue/<topic>.log), so its
  state persists across process runs.

  Scenario: A fresh topic starts with nothing pending
    Given the program
      """
      include "{lib}/queue.patlang"
      queue_remove_topic("spec_scratch_mq_fresh")
      print(list_len(queue_pending("spec_scratch_mq_fresh")))
      """
    When it runs interpreted and compiled
    Then both print
      """
      0
      """

  Scenario: consume returns the oldest pending message without acking it, and ack removes exactly that one
    Given the program
      """
      include "{lib}/queue.patlang"
      let t = "spec_scratch_mq_topic"
      queue_remove_topic(t)
      let id1 = queue_publish(t, "first message")
      let id2 = queue_publish(t, "second message")
      print(queue_consume(t))
      print(list_len(queue_pending(t)))
      queue_ack(t, id1)
      let pending = queue_pending(t)
      print(list_len(pending))
      print(("" + pending[0]) == ("" + id2))
      queue_remove_topic(t)
      """
    When it runs interpreted and compiled
    Then both print
      """
      first message
      2
      1
      true
      """
