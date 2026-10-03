# Report format

Offline commands accept `--format json` and write one JSON document to standard output. Diagnostics and any output printed while evaluating the trusted specification file go to standard error. Human output is the default.

Every document includes `schema_version` (`1`), `specproof_version`, `kind`, and `errors`. A check or plan configuration, usage, or I/O error keeps its requested `kind` and puts a stable `code`, explanatory `message`, and optional `path` and `source` in `errors`. An invalid command with no supported command kind uses `kind: "error"`. Every source object requires a file `path` and one-based `line`; schema 1 permits additional fields, and consumers must tolerate unknown source fields. The additive `kind` field identifies source provenance (for example, `dsl` or `rbs`) without changing existing fields or obligation identity.

Check and plan results include `contract_digest`, a SHA-256 digest of normalized declarations, behavioral input domains, partition policies, and sorted explicitly excluded input names. Exclusion reason, source location, and declaration order do not change the digest. With no exclusions, existing digests and criterion/obligation IDs remain unchanged. Source locations are excluded from this digest. For composed DSL/RBS declarations, the digest fingerprints the resulting behavioral input domains: broader type constraints, provenance, RBS text, parser version, and implementation behavior do not change it. Obtain a fresh runtime report after changing a source or implementation; matching digests establish the same analyzed input obligations and excluded names, not that a particular implementation is correct. Check results include `findings`, each with a semantic `code`, target and input names, a concrete `witness`, and source locations. Findings never appear in `errors`.

Successful check, plan, and runtime coverage documents share a `scope` object
with `completeness_scope: "analyzed_inputs"` and `input_scope`. Each input
scope entry identifies one target, its `analyzed_inputs` names, and its
`excluded_inputs`, each containing a parameter `name`, a human-readable
`reason`, and declaration `source` (`path`, one-based `line`, and `kind`). An
excluded name is part of the contract identity; its reason and source are
reported for review but do not change identity. Default scope is strict: every
named runtime parameter must be analyzed or explicitly excluded, and at least
one must be analyzed. Check/plan scope describes the requested declaration;
it does not attest runtime binding or test execution.

Plan results default to `criterion: "input-basics-v1"` and include `obligations`. Each scalar obligation has a stable `id`, target, input, typed value, merged reasons, and source locations. Values have a `kind`: integer values are decimal strings, symbols are names, booleans are JSON booleans, nil has a JSON null value, and finite strings use `{ "kind": "string", "value": "..." }`. String values are exact text snapshots. This is an additive value kind under schema version 1; consumers must handle it explicitly and tolerate it wherever typed primitive values occur, including witnesses and coverage rows. Strings and same-spelling symbols have distinct identities. Finite string values are deduplicated and ordered deterministically after existing scalar types. Existing nonstring IDs and digests remain unchanged. Existing partition, exhaustive, and disjoint checks apply to the explicitly enumerated string scenario. Scalar candidates are marginal inputs and do not specify expected method results or form a complete test suite.

## Pairwise finite criterion

Pairwise planning is opt-in. The Ruby API accepts
`SpecProof.plan(..., criterion: "pairwise-finite-v1")`; the CLI accepts
`specproof plan PATH --criterion pairwise-finite-v1`; the Minitest adapter
accepts `criterion: "pairwise-finite-v1"`. The default remains
`input-basics-v1`. `check` is criterion-independent and rejects `--criterion`.
A pairwise plan requires a valid `combinations` group for every supplied target;
it never skips a target that lacks a group.

Each target has at most one group over at least two distinct analyzed finite
inputs. Select either `all_allowed: true` with no block, or a nonempty block of
explicit `forbid` assignments. `all_allowed: true` declares that every tuple
is allowed; it is not evidence that inputs have independent effects. A
`forbid` clause must be justified by a stated requirement. Clauses are
conjunctive within a tuple and a tuple is forbidden if any clause matches.
Partial clauses restrict every completion. They are declarative data and do
not execute predicates. A forbidden tuple can still contain individually
feasible pairs when a third input differs; pair feasibility is determined by
whether the pair has an allowed full group completion.

Pairwise plan and runtime rows share `id`, `target`, `reasons`, `sources`,
`status`, and `hits`, and serialize their two assignments in `inputs` as a
name-to-typed-value object. Pair names are sorted canonically, while value
types remain significant; strings and same-spelling symbols are distinct.
Pairs excluded because no allowed full assignment completes them appear in
`excluded_pairs`, with `target`, typed `inputs`,
`reason: "no_allowed_completion"`, and relevant constraint sources. Excluded
pairs are not denominator rows. Do not remove a missing required pair by
adding a forbidden rule: the rule must come from an independent requirement.

Pairwise planning bounds each target to 10,000 full group assignments and
10,000 possible pair rows, and bounds all planned pair obligations to 10,000.
Oversized spaces fail with `combination_limit_exceeded`; SpecProof does not
sample or truncate. A valid declaration whose restrictions leave no allowed
full assignment produces the semantic finding `unsatisfiable_combinations`
and no plan. Malformed declarations are configuration errors. Pairwise
coverage counts only fully valid analyzed tuples; a forbidden runtime tuple
fulfills no pair obligations and is reported in the existing outside-domain
evidence with the added `outside_combinations` evidence. Selected inputs must
all be valid even when the combination group covers only a subset. Excluded
runtime inputs remain outside the claim, including any behavior involving
their values.

Finite string support is feature-specific, not guaranteed by a `0.1.x` version number. Check a fresh plan from the installed build for typed string obligations before relying on the kind. A finite string declaration enumerates scenario values and does not represent the full String domain. Only exact String instances with valid UTF-8 or US-ASCII encoding are supported; US-ASCII is canonicalized to UTF-8. Empty strings, whitespace, Unicode, and embedded NUL are valid text. Invalid byte sequences, other encodings, and String subclasses are rejected. No trimming, case folding, or Unicode normalization is applied. Declaration values and observed values are copied into frozen SpecProof-owned snapshots. The entry snapshot is used for matching even if the method mutates its argument, and direct Coverage observation also owns retained strings. A bounded outside-domain witness count does not bound witness bytes: a retained string witness is the full immutable string.

For a target also selected from RBS, DSL refinements must name parameters in
that selected signature. An extra DSL input produces configuration error
`rbs_input_mismatch`, with its DSL source and the RBS location in the message;
check/plan exit 2 without a successful partial plan. Unselected DSL-only targets
remain valid. RBS string literals, finite unions of supported string literals,
and optional string-literal forms import exact finite string scenarios without
duplicate DSL inputs. Same-spelling strings and symbols remain distinct.
Unrestricted `String` and selected unions with unsupported members fail
atomically. RBS return types are ignored; this checks input declaration names,
not Ruby arity/order or output conformance.

Finding witnesses use the same tagged primitive values, including the string kind above. Integer gap and containment witnesses are an array of two tagged integers denoting inclusive lower and upper bounds. Overlap witnesses are one tagged primitive. An empty-domain witness is either an empty finite array or the normalized, inverted integer bounds. For example, a gap from 65 through 120 is `[{"kind":"integer","value":"65"},{"kind":"integer","value":"120"}]`. Human reports quote and escape string values; other values retain ordinary Ruby notation.

`specproof skills export --to DIRECTORY --format json` results use `kind: "skills_export"` and add the expanded `destination` plus sorted `exported` and `unchanged` path arrays. The exporter requires an explicit destination and does not modify client or global configuration. A conflict is reported under `errors` before new files are copied.

Exit status is `0` for a successful command, `1` for semantic findings, and `2` for malformed configuration, unsupported options, usage errors, or I/O failures. A plan with semantic findings contains no obligations and returns status `1`.

## Minitest coverage

The optional adapter writes a JSON file with `kind: "coverage"` and prints a summary containing the same `run_id`. A successful report is evidence for that run only. Its contract digest does not fingerprint the implementation or tests; obtain a new run after either changes.

| Field | Meaning |
| --- | --- |
| `contract_digest`, `criterion` | Current normalized specification and selected input criterion (`input-basics-v1` or `pairwise-finite-v1`); compare with a current plan |
| `scope.completeness_scope`, `scope.input_scope` | Declared input scope: analyzed parameter names plus explicitly excluded names and their reasons/sources |
| `run_id` | Fresh UUID for the invocation, also printed in its summary |
| `completion` | `running`, `completed`, or `incomplete` |
| `integrity` | Whether collection and reporting completed without a known integrity failure |
| `tests_passed` | Original Minitest result; `null` before a result or when the runner aborts |
| `obligations` | Planned obligations plus `status` and integer `hits` counters |
| `missing`, `exercised` | Projections of the corresponding obligation rows |
| `exercised_count`, `missing_count`, `unknown_count`, `not_observed_count`, `obligation_count` | Counts over the fixed planned denominator |
| `completion_percent` | Percentage of exercised obligations for an intact observed run, including partial coverage; `null` when collection is incomplete or no target call was observed |
| `outside_domain` | Per-target count and at most one typed primitive tuple witness (including string values), or an `invalid_tuple` marker; these calls fulfill no valid-input obligations |
| `outside_combinations`, `excluded_pairs` | Jointly forbidden runtime tuple evidence and plan pairs with no allowed full completion; excluded pairs are outside the denominator |
| `incomplete_reasons`, `errors` | Bounded diagnostics explaining missing integrity or unsupported collection |
| `evidence_mode`, `replay` | `obligation_hits` and `false`; no full event trace is retained |

An obligation is `exercised` when a valid analyzed-input tuple supplied its candidate value; `not_observed` when collection was intact but no such tuple was seen; or `unknown` when an integrity limitation prevents concluding absence. Positive hits remain positive after an integrity failure, but unhit affected obligations become unknown. The `missing` array contains only `not_observed` rows. Every analyzed input in a call must satisfy its domain before any candidate from that call counts. Explicitly excluded values are outside the tuple and are never read by the collector; their values and behavior are not covered. An analyzed non-primitive value still makes collection incomplete. The collector does not silently drop undeclared parameter fields to make a tuple count: declaration names must account for the selected target's complete named runtime signature, split only between analyzed and explicitly excluded inputs.

Runtime `scope.targets` lists every target in the composed contract, and runtime `scope.declaration_sources` records the supplied declaration inputs as `{ "specifications": [...], "rbs": [...], "targets": [...] }`: canonical DSL and RBS paths, plus explicitly selected RBS targets. These runtime-only invocation fields do not attest that expected test files were loaded. Runtime scope also includes the shared `completeness_scope` and `input_scope` fields described above, plus the Ruby engine, process ID, run thread identity, run arguments, recognized inclusion `filter` and `exclude` patterns, `window: "minitest_run"`, and `method_identity: "direct_owner_definition"`. It records `input_semantics: "effective_bound_values"` and `argument_presence: "not_observed"`. Inspect the original arguments as well as the pattern summaries before treating the invocation as the intended full suite; patterns do not attest which test files the caller loaded. Reports apply to the current process, selected thread, and Minitest run window. They do not merge child-process or child-thread activity or identify individual tests.

`SpecProof::Minitest.install!` accepts the same optional `rbs:` and `targets:` inputs as `SpecProof.load`. A RBS-only setup may pass `specifications: []` when it supplies both a non-empty RBS path list and selected targets. File, parser, and type validation happens during run preparation so failures produce an incomplete report while the original Minitest result remains available in `tests_passed`. Empty RBS options preserve DSL-only behavior.

Named required and optional positional/keyword parameters are supported when every parameter is either an analyzed `input` declaration or an explicit `exclude_input` with a reason, and at least one parameter remains analyzed. Entry observations contain effective analyzed values after Ruby applies defaults. Omitted and explicitly supplied equal values exercise the same obligation; neither a hit nor its count establishes argument omission. The collector does not evaluate defaults, retain call-site argument presence, or add omission-specific obligations. Defaults that raise before entry yield no target entry evidence and preserve Ruby's exception. Defaults calling another selected method can contribute that other method's own entry observations within scope. A non-primitive analyzed value makes collection incomplete; primitive analyzed values outside a declared domain invalidate the entire analyzed tuple. Excluded values are not read. Rest, keyword-rest, forwarding, and explicit block parameters remain unsupported.

Method identity is the selected owner's directly defined public Ruby instance method, bound before observation begins. Calls through aliases of that same definition count. A subclass override contributes only when it executes the selected definition through `super`; a distinct override does not count merely because its method name matches. Aliased or inherited target declarations, unsupported signatures, and unresolved/autoloaded target owners fail binding. Two target names resolving to the same owner and method fail with `duplicate_binding`. Observed redefinition invalidates collection. Removing, rebinding, or replacing the selected constant path with an autoload at the end of collection produces `target_binding_changed`; previously observed hits remain, and unobserved obligations become unknown. Constant bindings must remain stable during the run; transient changes restored before final inspection are outside this guarantee. Supported runtime compatibility is CRuby 3.3, 3.4, and 4.0 with Minitest >= 5.26.2 and < 5.28.0, requiring matching package/runtime major and minor versions.

Before collection, the adapter atomically replaces any previous report with a marker for the new run, `completion: "running"`, `integrity: false`, and `tests_passed: null`. Finalization replaces it with the new run's final report. An interrupted run cannot leave an old successful report presented as current evidence. A report-write failure fails the adapter run and prints a diagnostic; a leftover running marker remains insufficient evidence.

Missing input obligations are informational by default. Strict missing mode can make the process fail even when `tests_passed` is true, because that field preserves the original assertion result. Assertion failures remain failures in either mode; collector/configuration integrity failures also fail the invocation. Input hits and assertion results are separate evidence: 100% input coverage does not establish behavioral correctness.

## Pairwise suggestions

`specproof suggest PATH --report FILE --format json` reads exactly one
completed coverage report and always uses `pairwise-finite-v1` with the
`greedy-pairwise-v1` strategy. It accepts the same optional `--rbs FILE` and
`--target TARGET` selectors as the other declaration commands. `--criterion`
is rejected because suggestions are defined only for pairwise reports.
Suggestions replan the supplied current declarations and validate the report
against the current contract digest, exact typed obligation denominator,
declared input scope, and consistent counters and projections. The source
report must have schema 1, kind `coverage`, completed and intact collection,
empty errors and incomplete reasons, zero unknown observations, and a Boolean
`tests_passed`. A false `tests_passed` value is accepted and preserved; it
records the original Minitest assertion result independently of coverage.
Filtered reports are accepted for their recorded scope. The output preserves
`source_run_id`, `source_tests_passed`, and `source_scope`; this does not make a
filtered run a full-suite claim.

The JSON suggestion document has schema 1, kind `suggestions`, no errors,
`criterion: "pairwise-finite-v1"`, `strategy: "greedy-pairwise-v1"`,
`assignment_scope: "combination_group"`, and
`minimality: "not_guaranteed"`. It includes the current `contract_digest`,
source provenance and scope, and `missing_obligation_count`,
`covered_obligation_count`, and `suggestion_count`. Each suggestion row has a
stable `id`, `target`, a full typed `inputs` assignment for its combination
group, `covers` containing only newly covered missing obligation IDs,
`unassigned_inputs`, and source locations. The union of `covers` is exactly
the source report's missing set. Inputs outside a combination group and
explicitly excluded inputs appear in `unassigned_inputs`; the caller must
supply them. Every analyzed runtime input, including those names, must still
be valid for a call to count.

Suggestions are unexecuted test inputs and contain no expected outputs. Use an
independent requirement as the assertion oracle, and never derive expected
values from the implementation or the suggestions. Do not copy a candidate
into a test without adding a meaningful assertion. A passing pairwise report
or a union of suggested pairs is evidence only for those finite input
combinations and assertions. The contract digest does not fingerprint
implementation or test bytes, so rerun the intended test suite in a fresh
process after either changes and inspect its new run ID and test result.

Suggestion generation is deterministic but greedy; it does not promise a
minimum number of assignments. It rejects work exceeding 10,000 cumulative
full assignments, 10,000 cumulative possible pair rows, 1,000,000 candidate
to missing-pair memberships, or a 32 MiB coverage report. It does not sample,
truncate, or emit partial results. CLI report reads are bounded to that size.
