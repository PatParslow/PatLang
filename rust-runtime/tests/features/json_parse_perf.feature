# Guards against a genuine wall-clock performance regression in json_parse,
# as opposed to the correctness-only parity checks elsewhere in this suite --
# a program that finishes with the RIGHT answer but takes 1700x longer than
# it should would pass every other test here. See also perf_regressions.feature.

Feature: json_parse stays linear in document size, not quadratic

  # GitHub #74: json_parse indexed its raw input string directly (`s[p]`,
  # `char_code(s, p)`, `s.length`, `substr(s, ...)`), and every one of
  # those host functions computes `s.is_ascii()` FRESH on every single
  # call (an O(document length) scan, not O(1)) -- so one left-to-right
  # parse of an n-character document paid O(n) work per character/token,
  # O(n^2) overall. Measured: 9m19s for a real 2.3MB document. Fixed by
  # having json_parse intern its input once (str_intern) and thread that
  # handle through every parse_* helper via sc_len/sc_code/sc_char (O(1)
  # once interned) and a new sc_substr (added alongside this fix, closing
  # the same gap for json_parse_number's numeric literal and json_parse_
  # string's \u escape, which called substr() once per TOKEN -- itself
  # O(n) calls for a document made of many small tokens, each paying the
  # same O(n) is_ascii() scan).
  Scenario: Parsing a 16,000-element flat JSON array compiles and runs natively in well under the old quadratic time
    Given a PatLang program:
      """
      include "lib/json.patlang"
      make a function called mk takes n returns s
        let b = sb_new()
        sb_push(b, "[")
        let i = 0
        while i < n do
          if i > 0 then
            sb_push(b, ",")
          end
          sb_push(b, "123")
          let i = i + 1
        end
        sb_push(b, "]")
        return sb_str(b)
      end
      let s = mk(16000)
      let v = json_parse(s)
      print(list_len(json_arr(v)))
      """
    When I compile and run it natively
    Then it prints exactly "16000"
    And the compiled run completes within 5 seconds
