Feature: fetch a real HTTPS page from parslow.net -- via a GOAP action wrapping curl (Tier A, no LLM)

  Background:
    Directly closes the gap left open by fetch_parslow_redirect.feature
    (PatLang's own tcp_connect/tcp_read has no TLS, so it can only ever
    see the 301 redirect a plain-HTTP request gets). Per the user's own
    idea: since curl (spec_library/shell/curl.feature) already has a
    real, hand-verified BDD spec confirming it genuinely fetches HTTPS
    content, wrap it as a single GOAP action instead of needing PatLang
    to implement its own TLS.

  Scenario: A single GOAP action, backed by curl, satisfies the goal directly
    Given goal have_a_real_page { have_response(parslow_page) }
    And one registered action, fetch_via_curl, bound to a closure that shells out to the real, spec-verified curl
    When pursue have_a_real_page then activate are evaluated
    Then activate returns true, and the real page's actual HTML (starting "<!DOCTYPE html>") is retrieved -- genuine HTTPS content, not a redirect stub

  Scenario: BLIND held-back check -- specific real article content, not just "some HTML"
    Given the fetched response, not inspected until after the visible HTML check already passed
    When checked for the literal text "Retro-fitting BDD" (the real article's own title, from a page written earlier this same session)
    Then it is present -- confirming genuine, specific page content was retrieved, not merely a plausible-looking HTML shell
