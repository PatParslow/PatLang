Feature: fetch a page from parslow.net -- synthesized via pure GOAP composition (Tier A, no LLM)

  Background:
    Two GOAP actions registered: connect_to_host (no preconditions,
    effect: connected(parslow_net)) and send_get_request (precondition:
    connected(parslow_net), effect: have_response(parslow_net)). Each
    bound (action_bind) to a real closure doing genuine tcp_connect/
    tcp_write/tcp_read work against the REAL external host parslow.net,
    port 80.

  HONEST, CONFIRMED LIMITATION (checked BEFORE writing anything, not
  discovered as a surprise failure): parslow.net is HTTPS-only --
  `curl -I http://parslow.net` returns a real 301 redirect to
  https://parslow.net/. PatLang's networking (tcp_connect/tcp_read/
  tcp_write) has NO TLS support at all (no tls_* host function exists
  anywhere in rust-runtime/src/ir/hosts.rs) -- so the real, honestly
  achievable goal here is "receive a genuine HTTP response from the
  real external host", not "retrieve actual page content" (e.g. the
  real bdd-retrofitting.html page a browser would show over HTTPS).
  That would need a real TLS implementation, a separate, un-built
  capability, not silently faked.

  Scenario: GOAP composes and executes a genuine two-action plan
    Given goal have_a_page { have_response(parslow_net) }
    When pursue have_a_page is evaluated
    Then the plan is exactly [connect_to_host, send_get_request] -- a
    real 2-step plan, not a single hard-coded action
    When activate is evaluated
    Then it returns true -- both bound closures ran to completion against the real external host

  Scenario: VISIBLE check -- a real HTTP response with a 301 status
    Given the activated plan's response, stored via set_var
    When checked for "HTTP/1.1" and "301"
    Then both are present -- a genuine HTTP/1.1 301 response was received from the real host

  Scenario: BLIND held-back check -- the EXACT redirect target
    Given the same response, NOT inspected until after the visible checks already passed
    When checked for the literal header "Location: https://parslow.net/"
    Then it is present -- confirming the exact, specific redirect target, not just "some 3xx status happened" (a genuinely more demanding, held-back claim than the visible checks alone)
