Feature: message queue (queue_publish/consume/ack/pending, self_hosting/lib/queue.patlang)

  Scenario: A fresh topic starts with nothing pending -- guarded, not assumed
    Given a scratch-only topic name never used elsewhere
    When `require to_num(list_len(queue_pending(topic))) == 0` runs first
    Then it passes -- confirming this is genuinely a clean start, not a leftover from a previous failed run

  Scenario: consume returns the oldest pending message without acking it
    Given two published messages ("first message", "second message")
    When queue_consume is called
    Then it returns "first message" -- FIFO order, and it remains pending until explicitly acked

  Scenario: ack removes exactly the acked message from pending
    Given the first message is acked by its id
    When queue_pending is read afterward
    Then only the SECOND message's id remains -- confirmed via an ensure guard on the exact remaining id, not just a count

  IMPORTANT (unlike the SQL/RDBMS specs above): this subsystem is
  backed by REAL disk files (.patlang_queue/<topic>.log via write_file/
  read_file), not the auto-isolated in-memory VFS -- state genuinely
  persists across process runs and needs EXPLICIT teardown (deleting
  the real log file), confirmed actually gone afterward, not just
  attempted.

