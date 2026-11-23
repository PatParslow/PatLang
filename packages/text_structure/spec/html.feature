Feature: text_structure HTML: units read through the PatLang DOM, each linked to its node
  An HTML text is read with the DOM (dom_from_html_spans), so every unit knows
  its DomNode and every node read knows its range in the file. A node found
  with the DOM's own queries is edited in place by its range and context, and
  the rest of the file stays byte for byte as it was.

  Scenario: headings make sections, and sentences run across inline elements
    Given the HTML
      """
      <html><head><title>T</title></head><body>
      <h1>Guide</h1>
      <p>The <em>first</em> one. And a <a href="x">second</a> one.</p>
      <h2>Steps</h2>
      <ul><li>Download it. Unpack it.</li><li>Run it<ul><li>Twice.</li></ul></li></ul>
      <div>Loose text in a div. Two sentences.</div>
      <pre>code. not sentences.</pre>
      </body></html>
      """
    Then its outline is
      """
      document
        section Guide
          heading
          paragraph: 2 sentences
          section Steps
            heading
            list
              item: 2 sentences
              item: 1 sentence
              item: 1 sentence
            paragraph: 2 sentences
            code
      """
    And the first paragraph's sentences are "The <em>first</em> one." and "And a <a href=\"x\">second</a> one."

  Scenario: a node found with the DOM is its unit, and editing it keeps the rest of the file as it was
    Given the HTML
      """
      <div>
        <p id="intro">Old words here.</p>
        <p  class='note'>Spacing   and 'quotes' as written.</p>
      </div>
      """
    When the node with id "intro" is found with dom_by_id, and its unit is made into "<p id=\"intro\">New words.</p>"
    Then the unit's node is that node, and the text is the same but for that paragraph
    And the second paragraph's odd spacing and quotes are as they were
