Feature: curl (real HTTPS fetching -- closes the TLS gap PatLang's own networking has)

  Scenario: Fetching a real HTTPS page returns its actual content
    Given a real, live page (https://parslow.net/teaching/learning/se/bdd-retrofitting.html)
    When `curl -s <url>` is run
    Then the real page's actual HTML is returned verbatim (confirmed by checking for its real DOCTYPE and known content), NOT PatLang's own tcp_connect/tcp_read (no TLS support -- would only ever see a 301 redirect to this same HTTPS url, never real content)

  Scenario: The real HTTP status code is reported
    Given the same real page and a deliberately nonexistent one
    When `curl -s -o NUL -w "%{http_code}" <url>` is run on each
    Then the real page reports 200 and the nonexistent one reports 404

  Note: this spec's own probe is deliberately coupled to one specific
  real external page (rather than a neutral/generic test target) --
  a deliberate choice, since the whole point of adding this spec was to
  prove real HTTPS content from THIS SITE is actually fetchable via
  curl, closing a real, named gap ([[patlang-synthesis-registry-experiments]])
  found in PatLang's own native networking.

