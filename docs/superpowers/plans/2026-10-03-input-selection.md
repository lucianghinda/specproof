# Explicit input selection implementation plan

> For agentic implementers: use superpowers-ruby:subagent-driven-development, with Luna implementation and independent specification/quality review.

**Goal:** Measure declared scalar inputs on ordinary methods that also accept explicitly excluded arguments, without weakening strict default collection.

**Architecture:** Selection belongs to the declaration and travels through the shared Specification model. An explicit exclusion records a name, nonblank reason, and source. The collector validates the entire named signature but only reads analyzed values. RBS imports only nonexcluded input types after validating all parameter names and existing method-shape restrictions.

**Stack:** Existing Ruby standard library, optional RBS 4.2.0 and existing Minitest integration. No new dependencies.

## Contract and example

```ruby
SpecProof.define "PStoreLogger#save" do
  exclude_input :data, reason: "Payload contents are outside this file-ID coverage scope"
  input :file_id, values: [nil, 1]
end
```

- Without exclusions, preserve existing exact parameter matching, whole-tuple validation, obligation IDs, criterion, and digest bytes.
- Analyzed and excluded names must be disjoint and together exactly match named runtime parameters. No implicit exclusions, wildcard exclusions, or zero-analyzed-input contracts.
- Exclusions require unique nonempty symbol names, a nonblank String reason, immutable copied data, and source provenance. Declaring and excluding a name in either order is an error.
- Excluded values are never read from the binding, validated, serialized, retained, or used to generate obligations. Their defaults and method execution still occur normally.
- Validate all analyzed values together: an out-of-domain analyzed value invalidates the analyzed tuple; a nonprimitive analyzed value makes collection incomplete. Existing redefinition, binding, thread/process, and failure protections remain.
- Existing unsupported method forms remain unsupported even if a parameter is excluded: rest, keyword-rest, blocks, forwarding, unnamed parameters, aliases, inherited/singleton methods, generic RBS owners/methods and overloads.
- RBS mixed loading accepts exclusions-only DSL when remaining RBS inputs provide finite domains. Validate excluded names against the selected signature before skipping their types. Typos, excluded/declared overlaps, excluded-all targets, undeclared DSL names and unsupported analyzed union arms fail atomically.
- The ordinary Loader default still requires at least one input. An internal mixed-load option may defer this check until composition; every final composed target requires an analyzed input. Unselected DSL-only targets cannot use exclusions-only declarations to create empty plans.
- Source-neutral Composer preserves exclusions and rejects excluded/type-fact collisions. The RBS adapter is responsible for deliberately removing excluded facts before composition.
- JSON check, plan and runtime reports identify analyzed inputs and excluded inputs with reasons/sources per target. Human check/plan/runtime output states any exclusions and explicitly limits completeness to analyzed inputs.
- Add canonical excluded names to digest material only for contracts with exclusions. Exclusion order, prose reason and provenance do not change semantic identity. Analyzed obligations retain the existing per-target/input/value/criterion IDs; consumers must also compare digest and scope.
- Selection does not validate excluded inputs, outputs, interactions, or whole-method behavior. Runtime reports continue to distinguish tests passed, collection integrity, and missing obligations.

## Task 1 — implement the complete selection path

Files: `lib/specproof/{model,loader,composer,collector,report,minitest,cli}.rb`, `lib/specproof.rb`, `lib/specproof/sources/{rbs,rbs_projector}.rb`, `sig/specproof.rbs`; focused tests under `test/` and `test/rbs/`.

- [x] Write failing declaration, composition, digest and report tests for the above contract.
- [x] Add immutable exclusion records and defaults on Specification; expose `exclude_input` in Builder.
- [x] Carry exclusions through composition and mixed RBS loading; reject invalid selections before planning.
- [x] Write failing collector/subprocess tests using an ordinary Hash payload and scalar option, including strict-default failures, typo/new parameter failures, analyzed invalid/nonprimitive values, original test failure preservation and no inspection of excluded objects.
- [x] Read only analyzed bindings while validating the combined named signature.
- [x] Share scope serialization across offline and runtime reports; expose exclusions in human output and update API declarations.
- [x] Verify default tests, optional RBS tests, lint and signatures. Obtain independent specification review then quality review; fix findings and rerun relevant checks.

Task 1 is committed as `23d6966`. The review found and fixed a missing RBS-name
check when every real RBS parameter was excluded; name validation now uses the
full signature before projection. The three-Ruby matrix passes 166 core tests
and 46 optional RBS tests per version. Locked RuboCop 1.90 inspects 98 files
without offenses.

Run core: `bundle exec rake`. Run optional: `BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby bin/test test/rbs/source_test.rb test/rbs/workflow_test.rb`. Run API validation: `BUNDLE_GEMFILE=Gemfile.rbs bundle exec rbs -I sig validate`. Use explicit installed Ruby paths and clean compatible Bundler environments on this host.

## Task 2 — document and exercise the agent workflow

Files: `README.md`, `docs/report-format.md`, `skills/specproof-{specify,test-gaps}/` and their references; a small runnable example under `examples/input_selection/` if the retained pilot alone is unsuitable for shipping.

- [x] Explain when selecting an input is a legitimate scoped question and that adding exclusions solely to silence a finding changes the question being answered.
- [x] Instruct agents to inspect scope and fresh digest, preserve independent behavioral assertions, and disclose exclusions in conclusions.
- [x] Update existing packaged skills without requiring an additional CLI/API selection option or duplicating RBS-derived scalar declarations.
- [x] Run installed package/export checks and fresh Luna scenarios for a requested scoped adoption and pressure to hide an analyzed-input failure. Retain commands, supplied tasks, results, exact skill hashes and fresh reports; do not claim a general reliability rate.
- [x] Obtain specification then quality review of the documentation/skills and example.

## Task 3 — adoption and final verification

Files: new `docs/pilots/input-selection/` evidence and `docs/input-selection-results.md`.

- [x] Copy the original PStoreLogger project at the previously recorded revision to scratch, preserving its ordinary Hash-based test suite and source hashes. Read its current source/requirements before selecting a meaningful scalar domain; do not assume all existing file IDs lie in `[nil, 1]`.
- [x] Run its unchanged uninstrumented tests, check/plan the scoped declaration, then the same ordinary suite with collection. Assert explicit `data` exclusion, selected file-ID evidence, fresh run ID, agreement with offline IDs/digest and original test outcomes.
- [x] If a missing obligation is supported by a documented behavior rule, add a separate meaningful assertion and rerun. If there is no justified gap, report adoption without inventing one. No outside project edits or relabeling prior incomplete reports.
- [x] Run core and optional tests on Ruby 3.3.6, 3.4.7 and 4.0.1; default lint, `bin/check`, optional signature validation, final diff checks.
- [x] Independently review the final implementation and retained pilot/evaluation claims; retain concise evidence and state limitations.
- [x] Commit completed slices using Lore messages on `implement/input-selection`; leave original and RBS checkouts unchanged. No publication or merge included.

## Acceptance decision

Success means an ordinary existing suite can produce honest, complete collection for deliberately selected scalar inputs despite object-valued excluded arguments; strict defaults and unsupported analyzed-input failures remain intact. Coverage gaps may remain and must be reported as such. Completeness is not evidence of assertion quality or whole-method conformance.
