# Deterministic pairwise suggestions implementation plan

**Goal:** Turn a completed pairwise coverage report into deterministic allowed group assignments that jointly exercise its missing pairs.

**Architecture:** Replan the current declarations, validate the supplied coverage evidence against that plan, and greedily choose allowed assignments. Keep declaration semantics, collection, and existing reports unchanged. A separate suggestion report discloses its source run and scope; it never claims execution or supplies expected behavior.

**Tech stack:** Ruby standard library, existing optional RBS/Minitest adapters; no new dependencies. Luna native subagents implement bounded, separately owned slices with specification and quality review.

## Accepted interface

```ruby
specifications = SpecProof.load(["specifications/delivery.rb"])
report = JSON.parse(File.read("tmp/coverage.json"))
result = SpecProof.suggest(specifications, report: report)
result.suggestions.each do |suggestion|
  suggestion.inputs # full combination-group assignment, native typed values
  suggestion.covers # newly covered missing obligation IDs
end
```

```sh
specproof suggest specifications/delivery.rb --report tmp/coverage.json --format json
specproof suggest --rbs sig/delivery.rbs --target 'Delivery#build' specifications/delivery.rb --report tmp/coverage.json
```

`suggest` always uses `pairwise-finite-v1` and strategy `greedy-pairwise-v1`; it rejects `--criterion` rather than providing an unused option. Exactly one nonempty `--report` is required. `--report` is rejected by check/plan. Existing CLI commands and defaults retain their behavior. No Minitest install option or automatic test execution is added.

Suggestions cover the **combination group**, not necessarily the complete method signature. Each row has `unassigned_inputs`: sorted names of analyzed parameters outside the group plus explicitly excluded parameters. These need caller-supplied values. A valid group assignment does not guarantee those other parameters are valid, that a call returns, or that assertions pass. All groups are selected from the supplied current specifications, with no silent target omission.

## Evidence contract

The API accepts a parsed JSON object with String keys. `CoverageReport.new(report, specifications:, obligations:)` validates it and exposes frozen `missing_ids`, `run_id`, `tests_passed`, and `scope` snapshots. Unknown additive fields are allowed; required fields cannot be missing or malformed.

Require schema 1, kind coverage, pairwise criterion, nonempty string run ID, completed collection, integrity true, empty errors/incomplete reasons, evidence_mode obligation_hits, replay false, and Boolean tests_passed. Both passing and failing assertions are accepted and preserved. Running/incomplete reports, unknown observations, scalar reports, and null test results are rejected atomically.

Require the current contract digest, exact target set and declared analyzed/excluded/group name scope. Compare each unique obligation's ID, target, and typed assignments against the fresh pairwise plan; require the exact denominator, not just matching counts or IDs. Status is exercised with positive Integer hits or not_observed with zero hits. Reject missing/duplicate/extra/altered rows, booleans masquerading as counts, and invalid value encodings. Verify all denominator/status counts and missing/exercised projections against the authoritative rows. Require unknown_count zero; verify completion_percent when present against the report's observed rows, accepting null for a no-observation run. Never trust the missing projection alone.

Filtered reports remain usable for their recorded scope, which is copied into the output. Scope arguments/filter/exclude must have their documented JSON types; no full-suite claim is made. Compare declared name scope independent of source locations, reasons, or input ordering. Declaration paths, code, and test bytes are not fingerprinted by the contract digest: no implementation/test freshness claim is possible. Documentation and skills require rerunning tests after those changes. Do not load application constants or execute tests while suggesting.

Configuration failures use stable codes: `invalid_coverage_report` for malformed/inconsistent content, `unsupported_coverage_report` for schema/kind/criterion mismatch, `incomplete_coverage_report` for insufficient collection evidence, `coverage_contract_mismatch` for differing digest/obligation/scope, `suggestion_limit_exceeded` for suggestion budgets. JSON parse errors also become invalid_coverage_report. Semantic specification findings remain exit 1 with no suggestions; configuration/report errors exit 2 with no partial suggestions. Valid empty missing sets return exit 0 and an empty suggestion list.

## Determinism, algorithm, and budgets

Expose `CombinationSpace#allowed_assignments` as a frozen array of deeply frozen group hashes, in canonical input-name and Domains.sort_key value order. Reuse its joint feasibility semantics; do not combine independently feasible pairs into an unchecked tuple.

For each target in sorted order, candidates are allowed full group assignments. Score by how many still-uncovered missing pairs the candidate contains. Choose the largest score, breaking ties by canonical typed assignment order; remove those IDs and repeat until none remain. Every output row has positive gain. `covers` contains only newly covered IDs in stable sorted order; their union must equal the source missing set, with no excluded/exercised IDs. Do not claim globally minimum suggestions. Preserve String/Symbol distinctions and own mutable String data. Equivalent declaration, rule, and report-row ordering must produce the same assignment sequence and stable suggestion IDs. IDs hash target, canonical typed assignments, pairwise criterion, and strategy; never source path or run ID.

The existing per-target 10,000-assignment/pair limits remain. Before suggestion generation, bound cumulative full group products and cumulative possible pair rows to 10,000 across targets, and candidate-to-missing-pair memberships to 1,000,000. Reject instead of sampling/truncating. Score updates should use an inverted membership index so removing a pair does not repeatedly intersect every candidate. A deterministic scan for the maximum score is adequate at the bounded size. CLI reads at most 32 MiB of report data (limit+1 bounded read, not a full unbounded File.read); larger reports fail suggestion_limit_exceeded. Report validation checks row cardinality against the already bounded plan before processing rows.

## Locked internal result/report interfaces

`Suggestion`: frozen `id`, `target`, `inputs` (native typed group Hash), `covers` (newly covered IDs), `unassigned_inputs` (Symbol names), `sources`.

`SuggestionResult`: frozen `suggestions`, `contract_digest`, `source_run_id`, `source_tests_passed`, `source_scope`, `missing_count`.

`Suggestions.new(specifications, report:).result` implements the API. Constants `CRITERION = "pairwise-finite-v1"`, `STRATEGY = "greedy-pairwise-v1"`. `SuggestionReport.document(result)` renders schema 1 kind suggestions, errors [], criterion, strategy, assignment_scope combination_group, minimality not_guaranteed, contract_digest, source_run_id/source_tests_passed/source_scope, missing_obligation_count, covered_obligation_count, suggestion_count, and suggestions. Rows serialize `inputs` as name-to-typed-value maps plus id/target/covers/unassigned_inputs/sources. Covered count is the union of covers, not observed coverage. `SuggestionReport.human(result)` shows source run/test result, scope, typed assignments, covered IDs and unsupplied parameter names, and explicitly says these are unexecuted suggestions with no expected results.

## Task 1 — checked evidence and deterministic engine

- [ ] Evidence owner: create `lib/specproof/coverage_report.rb`, `test/coverage_report_test.rb`. Add failing tests from real adapter-shaped JSON for contract/scope/typed row mismatch, duplicate IDs, inconsistent counters/projections, incomplete/unknown reports, false test results, filtered scope, and immutable snapshots. Implement the validation gate above.
- [ ] Engine owner: create `lib/specproof/suggestions.rb`, `test/suggestions_test.rb`; modify `combinations.rb`, `lib/specproof.rb`, `sig/specproof.rbs`. Add public API and immutable records, frozen allowed assignments, deterministic greedy selection and limits. Declare `require_relative "specproof/coverage_report"` before suggestions in the library entry point.
- [ ] Prove three booleans with no hits produce a deterministic covering set; two booleans with 00/01/10 produce only 11; a forbidden triple is never suggested despite all its constituent pairs being feasible elsewhere. Test indirect exclusions, type/order invariance, existing hits, no missing pairs, multi-target ordering, subset/excluded unassigned names, immutability and all resource rejection paths.
- [ ] Run focused tests red then green and scoped lint; integrate and obtain independent specification review before quality review.

## Task 2 — command and agent-facing output

- [ ] CLI owner: modify `lib/specproof/cli.rb`; create `lib/specproof/suggestion_report.rb`, `test/suggestions_cli_test.rb`. CLI can require its report helper directly. Add `suggest`, reuse declaration loading/RBS selection, bounded JSON reading, human/JSON output and stable atomic diagnostics. Preserve parsing subsequent options after the first error so --format json still works.
- [ ] Test CLI success/empty result, report missing/duplicate/unknown options, invalid JSON/oversize reports, incompatible contracts, semantic spec failures, failure flags preserved, string quoting, paths with spaces, subset scope, and no modification of input report/spec/test files. Run subprocess workflow with real Minitest-generated coverage.
- [ ] Documentation owner: update README, docs/report-format.md, both packaged skills plus usage references, and add runnable `examples/pairwise_suggestions/` with normative requirements. Demonstrate baseline -> suggest -> new independent assertion -> fresh report, preserving failing assertions if a defect is exposed. Reuse the existing pairwise fixture where useful; never derive expected output from the suggestion or implementation.

## Task 3 — adoption, installed skills, verification, commits

- [ ] Identify and execute one suitable real-project pilot with an independent behavior oracle; preserve original source/tests and retain a focused before/after report, suggestions, added assertion, commands and hashes. If local candidates genuinely cannot meet supported semantics, document concrete rejection evidence and the resulting limitation rather than fabricate a success.
- [ ] Run an old-skill baseline and a fresh installed/exported-skill Luna actor. Challenge stale or incomplete evidence and attempts to narrow forbids; validate useful suggestions without generated expected results. Retain concise auditable artifacts with historical Ruby as .txt.
- [ ] Run all core/optional RBS tests and signature validation on Ruby 3.3.6/3.4.7/4.0.1; locked default rake/lint, packaging and diff checks. Review final code and evidence; record results and remaining limits.
- [ ] Commit implementation and evidence with Lore messages on implement/pairwise-suggestions. Keep main unchanged; no publication or merge in this task.
