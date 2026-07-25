Feature: tpl_raw (self_hosting/lib/template.patlang)

  Scenario: Wraps HTML in a Raw node unchanged
    Given "<div>hi</div>"
    When tpl_raw is applied
    Then the result is ["Raw", "<div>hi</div>"] -- no escaping, no validation, a plain tagged constructor

