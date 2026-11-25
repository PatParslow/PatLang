Feature: text_structure facts: a document's structure as facts, rules over it, and facts kept current
  A numbered tree's units are facts in a logic store, as relations: unit,
  child, attr and words, never positions. Rules about the writing are rules
  over them. After an edit, ts_update and ts_facts_update change only the
  facts of what changed, and the rules answer as they would over a fresh read.

  Background:
    Given the Markdown document for the facts
      """
      # Guide

      A short sentence. This sentence goes on and on with one word after another until it has far more than forty words in it, which is more than anyone reading it would want, so a rule about the writing should find it and say so, as it does here.

      ## Empty

      ## Code

      ```
      no language named
      ```

      ## One

      A paragraph of the first more section. It has two sentences.

      ## Two

      Another paragraph. With two sentences too.

      ## Three

      A third paragraph here. And its second sentence.

      ## Four

      - an item. With two sentences.
      - another item.

      ## Five

      The last paragraph. It ends the document.
      """
    And its tree numbered and put in a store as facts, with the document rules

  Scenario: the document rules find the long sentence, the empty section and the code with no language
    Then long_sentence finds one sentence, starting "This sentence goes on"
    And empty_section finds the section "Empty"
    And untitled_code finds one code block

  Scenario: after an edit the facts change only for what changed, and the rules answer as over a fresh read
    When the short sentence is made long by an edit, and the tree and the facts are updated from its shifts
    Then fewer than a fifth of the facts were taken out or added
    And long_sentence finds two sentences, the same as over a fresh read of the new text
    And the store holds as many facts as a fresh read's would

  Scenario: a goal that every section has content is planned from the facts and carried out as one batch
    When the goal that every section has content is planned and carried out, with the filler "To be written."
    Then the plan has one step, for the section "Empty"
    And the section "Empty" now holds the paragraph "To be written.", empty_section finds none, and the facts are a fresh read's

  Scenario: when the files service refuses the plan's batch, the goal is planned again from the file as it now is
    When the text is a file kept by the files service, and another client renames the section "Empty" to "Blank" just before the plan's first batch arrives
    And the goal that every section has content is pursued through the service, with the filler "To be written."
    Then it took two rounds, the first batch refused
    And the file's section "Blank" now holds the paragraph "To be written.", and empty_section finds none in it

  Scenario: a refusal with no change to the file ends the pursuit, since planning again would plan the same
    When the goal that every section has content is pursued through a service that refuses every batch and changes nothing
    Then the pursuit is refused after one round, giving the service's reason
