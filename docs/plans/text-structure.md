# Text structure: sections, paragraphs and sentences, for edits by address

Decided 2026-11-23: a package of its own (`packages/text_structure`), with a
common core and a structurer for each format: Markdown and plain text first,
then Gherkin features and program code (PatLang first). Sentences follow
Unicode's UAX #29 (Unicode Text Segmentation), its Sentence_Break data and its
conformance test, rather than heuristics of our own, tailored with CLDR's
English sentence-break suppressions. It works with the files service
(`docs/plans/file-marshal.md`) without the service knowing any format.

Sources, kept in `D:\Projects_Organized\SourceLibrary\unicode-text-segmentation\`:
UAX #29 (Unicode 18.0), `SentenceBreakProperty.txt` and `SentenceBreakTest.txt`
(Unicode 18.0.0, 2026), and CLDR's `common/segments/en.xml` (its suppressions),
all under the Unicode licence, which allows their use and redistribution with
the notice kept.

## The core

A text's structure is a tree of units. Each unit is
`[kind, start, end, attrs, children]`: its kind (`document`, `section`,
`heading`, `paragraph`, `sentence`, `list`, `item`, `code`, `quote`, `table`,
and each format's own), its range in the text's UTF-8 bytes, a few attributes
(a heading's level and title, a code block's language, a step's keyword), and
the units inside it. Ranges nest, and a unit's children lie in its range in
order.

- **Addresses**: a unit is named by a path from the root, by kind and number or
  by title: `section "Design" / paragraph 3 / sentence 2`, numbered from 1 as
  the edits number their refusals. `ts_find(tree, address)` gives the unit, or
  why there is none (no such title, or a title held twice).
- **Walking**: `ts_walk(tree, kind)` is a fibre that yields each unit of a kind
  in order, so a search that stops at the first match reads no further.
- **Edits by address**: `ts_edit_for(text, unit, new)` is a file_marshal edit
  whose context is the bytes around the unit (as undo takes its context), so
  it still applies when the file has moved on; `ts_insert_before`,
  `ts_insert_after`, `ts_delete` and `ts_move` likewise, a move being one batch
  of a delete and an insert.
- **Keeping current**: after edits, the tree is carried through their shifts
  (`fm_map_position`) rather than built again. A unit with a boundary inside a
  change is built again, and only it: the smallest paragraph or section that
  holds the change.

## Sentences: UAX #29

- The Sentence_Break value of every code point comes from
  `SentenceBreakProperty.txt`, made into a table of ranges by a generator in the
  package (`tools/make_sentence_table.patlang`), which writes
  `sentence_table.patlang` with the data file's version and notice. The data
  file is kept in the package beside it.
- The rules are SB1 to SB998 as UAX #29 section 5.1.1 gives them, over code
  points read from the UTF-8 bytes, with Extend and Format ignored as SB5 says.
- **Conformance**: every line of `SentenceBreakTest.txt` (512 in 18.0.0) must give
  exactly the breaks it marks. This is the check that the rules are right.
- **Tailoring**, applied after the default rules, and each with tests of its own:
  - In a paragraph, a single line break is a space: UAX #29 counts every LF as
    a paragraph separator (SB4), which would end a sentence at the end of each
    line of wrapped text. Paragraphs are found first, by each format's rules,
    and the default rules then run inside each one.
  - CLDR's English suppressions: no break after one of its abbreviations
    ("Mr.", "e.g.", "U.S.", ...), where the default rules would put one before
    an uppercase word (UAX #29 notes it cannot tell "...Mr. Jones...").

## The formats

- **Plain text**: paragraphs at blank lines; sections only where a line is
  underlined with `=` or `-` (a title), else the whole text is one section.
- **Markdown** (CommonMark's block structure, as far as the units go): ATX (`#`)
  and setext headings make nested sections; fenced and indented code, block
  quotes, lists and their items, tables and thematic breaks are units of their
  own; sentences only in paragraphs, list items and quotes, never in code.
- **Gherkin**: feature, rule, background, scenario (and outline), examples,
  step, doc string and table; a step's keyword in its attrs; the description
  lines under a feature or scenario as paragraphs, with sentences.
- **Program code**, PatLang first: functions (`make a function called`),
  classes, top-level statements, comments as paragraphs with sentences, and
  string literals left whole. Other languages later, on the same core.

## HTML, and the PatLang DOM

HTML is a format like the others, read through `lib/dom.patlang`'s tree, so a
program that holds a `DomNode` and one that holds a unit are holding the same
thing. Today neither the tokenizer (`html_tokenize`) nor `dom_from_html` keeps
where a token or a node was in the source, so:

- `html_tokenize_spans(html)` gives the tokens `html_tokenize` gives, each with
  its range in the source after it; `html_tokenize` itself is unchanged.
- `DomNode` gains `start` and `end` (-1 for a node not read from a source), set
  by `dom_from_html_spans(html)`: an element from its open tag's `<` to its
  close tag's `>`, a text node over its text. The tokenizer counts characters,
  and the units count UTF-8 bytes; `ts_decode` gives each character's byte, so
  the ranges are carried over once.
- The HTML structurer makes units from the tree: `h1` to `h6` start sections
  (and `section`, `article` and `main` are sections of their own), `p`, `li`,
  `blockquote`, `pre`, `table` and the rest as their kinds, and sentences in a
  block's text across its inline elements (`em`, `a`, `code`), which run
  straight on (a text view range marked to join with no space), with `br` as
  a space. An entity is read as written for the sentence rules ("&amp;" is
  five characters to them), which changes a boundary only in odd cases; the
  DOM's own text has it decoded. HTML's sectioning elements (`section`,
  `article`, `main`) hold blocks and are not sections of their own yet:
  headings make the sections.
- Each HTML unit's attrs name its node, and `ts_node_of(unit)` and
  `ts_unit_of(tree, node)` go each way, so a program can find a node with the
  DOM's queries (`dom_by_id`, `dom_by_class`) and edit its range in the file by
  context, keeping the rest of the file byte for byte, where writing the tree
  out again would change its spacing and quoting everywhere.
- html_scan reads well-formed markup of the kind the site's pages are; the
  HTML5 parsing algorithm (implied end tags, misnested elements) is not
  attempted, and a page it would mend is read as it is written.

## Logic and goals

The structure and the history are facts, and the structural edits are actions,
so the logic store and the planner can use both:

- **The structure as facts**: `ts_to_facts(tree, store, doc)` adds, to a store
  the program gives (never the default one), `unit(Doc, Id, Kind)`,
  `span(Id, Start, End)`, `child(Parent, Id, N)`, `attr(Id, Key, Value)` and,
  for sentences, `words(Id, N)`. A document's rules are then rules: "a section
  with no paragraph", "a heading two levels below the one before it", "a
  sentence of more than 40 words", "a link to an id no element has", each a
  `rule_add_to` and a `solve_in`, so a site's or a repository's writing rules
  can be checks over its files rather than code for each. The DOM gets the
  same, `dom_to_facts`, for HTML read without structure.
- **The history as facts**: `fh_to_facts(h, store, path)` gives
  `version(Path, V, Kind, Client, Time)` and `touched(Path, V, Start, End)`
  (an edit's range, carried to the current version through the shifts after
  it). "Which versions changed this section" and "who last edited this
  paragraph" are then queries.
- **Goals and plans**: the structural edits are actions (`action_add`), with a
  unit's existence and its place as preconditions and the facts they change as
  effects, so a goal about a document ("every section starts with a summary",
  "the headings never skip a level") is planned with `plan_in` from its facts.
  The plan's steps become edits by address and go to the files service as one
  batch, applied all or none: a plan is carried out whole or not at all. When
  the service refuses it (someone else's edit moved the context), the facts are
  read again from the new version and the goal planned again, which is the
  replanning the goal-oriented programs already do.
- These sit on top of the core and cost nothing to a program that does not use
  them; they come after the formats.
- **Keeping the facts current** (from step 4): `ts_update` re-reads only a
  region and carries every other block, so facts can follow it at the
  region's cost if they do not hold positions. Each unit gets an id when it is
  read, kept in its attrs and carried by `ts_update` with the block; the facts
  are the relations (`unit`, `child`, `attr`, `words`), which do not change
  for a carried block, and a unit's range is read from the tree when a rule
  needs it (`ts_span_of(tree, id)`), never stored as a fact. After an update,
  the facts of the ids that left (the region's old blocks) are taken out, and
  those of the region's new blocks added; the sections, made again over the
  blocks, change only their `child` facts. The cost of keeping a document's
  facts is then that of the edit, not of the document.
- A plan's batch goes to the files service, whose reply carries the shifts;
  `ts_update` with those shifts gives the tree, and the fact update above the
  facts, so the next goal is planned from the new state without a full read.

## With the files service

The service stays as it is, with no knowledge of formats. A client reads a file
(content and version), builds its tree, makes an edit by address, and sends it
as an edit with that version as its base; the service carries its hint and
applies it by its context. A client holding a tree from an older version asks
for the shifts since then and carries its tree forward. An `outline` request in
the service, giving the tree for a format, can come later if clients that do
not want to parse ask for it.

## Order

Done 2026-11-23: steps 1 to 5 (`sentences.patlang`, `structure.patlang`,
`plain.patlang`, `markdown.patlang`, `html.patlang`, `update.patlang`; spans in
`lib/html_scan` and `lib/dom`, checked in `dom_selftest`), 45 checks
interpreted and compiled. Step 4's test is a property: after each of 200
random edits to Markdown and 100 to plain text, the updated tree equals a full
read; on 290 KB, one sentence changed re-reads 80 bytes, in 328 ms against a
full read's 10 s (before the ASCII class table, which made a full read about
ten times faster). An edit by address takes, where its context repeats within
1 KB of its place, the candidate nearest its place (`fm_nearest`): a document
can repeat its own text so that no context near a unit is unique.

1. The sentence table from the data file, the UAX #29 rules, and the
   conformance test (all 512 lines), interpreted and compiled.
2. The core tree, addresses, the walk as a fibre, and edits by address.
3. Plain text and Markdown, with the two tailorings and their tests.
4. Keeping a tree current through shifts.
5. HTML, with spans in html_scan and the DOM, and units linked to nodes.
6. Gherkin, then PatLang source.
7. Facts and goals: the structure, the DOM and the history as facts, document
   rules as `rule_add_to` and `solve_in`, and structural goals planned and
   carried out as one batch.
