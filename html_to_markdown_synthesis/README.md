# Experiment: GOAP/ILP program synthesis targeting an HTML-to-Markdown CLI

This directory is an experiment, not a maintained tool or library. It used
PatLang's synthesis engines (GOAP action planning in
`goap_snippet_synthesis.patlang`, and ILP/LGG example-driven synthesis in
`synthesis_lgg.patlang`), plus a specification-completeness analyzer
(`spec_analyzer.patlang`), to see how far those engines could get toward
assembling an HTML-to-Markdown converter from Gherkin-style examples and
action templates.

See `synthesis_failure_points_report.md` for the write-up of what worked,
what didn't, and the failure modes found along the way.

Left as-is (uncommitted-work cleanup pass, 2026-09-12): kept for reference,
not folded into the supported self-hosted toolchain.
