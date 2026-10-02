# Report format

Offline commands accept `--format json` and write one JSON document to standard output. Diagnostics and any output printed while evaluating the trusted specification file go to standard error. Human output is the default.

Every document includes `schema_version` (`1`), `specproof_version`, `kind`, and `errors`. A check or plan configuration, usage, or I/O error keeps its requested `kind` and puts a stable `code`, explanatory `message`, and optional `path` and `source` in `errors`. An invalid command with no supported command kind uses `kind: "error"`. Every source object requires a file `path` and one-based `line`; schema 1 permits additional fields, and consumers must tolerate unknown source fields. The additive `kind` field identifies source provenance (for example, `dsl` or `rbs`) without changing existing fields or obligation identity.

Check and plan results include `contract_digest`, a SHA-256 digest of normalized declarations, behavioral input domains, and partition policies. Source locations are excluded from this digest. For composed DSL/RBS declarations, the digest fingerprints the resulting behavioral input domains: broader type constraints, provenance, RBS text, parser version, and implementation behavior do not change it. Obtain a fresh runtime report after changing a source or implementation; matching digests establish the same normalized input obligations, not that a particular implementation is correct. Check results include `findings`, each with a semantic `code`, target and input names, a concrete `witness`, and source locations. Findings never appear in `errors`.

Plan results include `criterion` (`input-basics-v1`) and `obligations`. Each obligation has a stable `id`, target, input, typed value, merged reasons, and source locations. Values have a `kind`: integer values are decimal strings, symbols are names, booleans are JSON booleans, and nil has a JSON null value. Candidates are marginal inputs and do not specify expected method results or form a complete test suite.

For a target also selected from RBS, DSL refinements must name parameters in
that selected signature. An extra DSL input produces configuration error
`rbs_input_mismatch`, with its DSL source and the RBS location in the message;
check/plan exit 2 without a successful partial plan. Unselected DSL-only targets
remain valid. This checks declaration names, not Ruby arity/order or output
conformance.

Finding witnesses use the same tagged primitive values. Integer gap and containment witnesses are an array of two tagged integers denoting inclusive lower and upper bounds. Overlap witnesses are one tagged primitive. An empty-domain witness is either an empty finite array or the normalized, inverted integer bounds. For example, a gap from 65 through 120 is `[{"kind":"integer","value":"65"},{"kind":"integer","value":"120"}]`. Human reports retain ordinary Ruby notation.

`specproof skills export --to DIRECTORY --format json` results use `kind: "skills_export"` and add the expanded `destination` plus sorted `exported` and `unchanged` path arrays. The exporter requires an explicit destination and does not modify client or global configuration. A conflict is reported under `errors` before new files are copied.

Exit status is `0` for a successful command, `1` for semantic findings, and `2` for malformed configuration, unsupported options, usage errors, or I/O failures. A plan with semantic findings contains no obligations and returns status `1`.

## Minitest coverage

The optional adapter writes a JSON file with `kind: "coverage"` and prints a summary containing the same `run_id`. A successful report is evidence for that run only. Its contract digest does not fingerprint the implementation or tests; obtain a new run after either changes.

| Field | Meaning |
| --- | --- |
| `contract_digest`, `criterion` | Current normalized specification and input criterion; compare with a current plan |
| `run_id` | Fresh UUID for the invocation, also printed in its summary |
| `completion` | `running`, `completed`, or `incomplete` |
| `integrity` | Whether collection and reporting completed without a known integrity failure |
| `tests_passed` | Original Minitest result; `null` before a result or when the runner aborts |
| `obligations` | Planned obligations plus `status` and integer `hits` counters |
| `missing`, `exercised` | Projections of the corresponding obligation rows |
| `exercised_count`, `missing_count`, `unknown_count`, `not_observed_count`, `obligation_count` | Counts over the fixed planned denominator |
| `completion_percent` | Percentage of exercised obligations for an intact observed run, including partial coverage; `null` when collection is incomplete or no target call was observed |
| `outside_domain` | Per-target count and at most one typed primitive tuple witness, or an `invalid_tuple` marker; these calls fulfill no valid-input obligations |
| `incomplete_reasons`, `errors` | Bounded diagnostics explaining missing integrity or unsupported collection |
| `evidence_mode`, `replay` | `obligation_hits` and `false`; no full event trace is retained |

An obligation is `exercised` when a valid complete input tuple supplied its candidate value; `not_observed` when collection was intact but no such tuple was seen; or `unknown` when an integrity limitation prevents concluding absence. Positive hits remain positive after an integrity failure, but unhit affected obligations become unknown. The `missing` array contains only `not_observed` rows. All inputs in a call must satisfy their domains before any candidate from that call counts.

`scope.targets` lists every target in the composed runtime contract. `scope.declaration_sources` records the supplied declaration inputs as `{ "specifications": [...], "rbs": [...], "targets": [...] }`: canonical DSL and RBS paths, plus explicitly selected RBS targets. These invocation inputs do not attest that the test files expected by a caller were loaded. Each source record's `kind` identifies its source family; consumers should treat this field as additive and allow new kinds. Scope also records the Ruby engine, process ID, run thread identity, run arguments, the recognized inclusion `filter` and `exclude` patterns, `window: "minitest_run"`, and `method_identity: "direct_owner_definition"`. It records `input_semantics: "effective_bound_values"` and `argument_presence: "not_observed"`. Inspect the original arguments as well as the pattern summaries before treating the invocation as the intended full suite; patterns do not attest which test files the caller loaded. Reports apply to the current process, selected thread, and Minitest run window. They do not merge child-process or child-thread activity or identify individual tests.

`SpecProof::Minitest.install!` accepts the same optional `rbs:` and `targets:` inputs as `SpecProof.load`. A RBS-only setup may pass `specifications: []` when it supplies both a non-empty RBS path list and selected targets. File, parser, and type validation happens during run preparation so failures produce an incomplete report while the original Minitest result remains available in `tests_passed`. Empty RBS options preserve DSL-only behavior.

Named required and optional positional/keyword parameters are supported when every parameter has an input declaration. Entry observations contain effective scalar values after Ruby applies defaults. Omitted and explicitly supplied equal values exercise the same obligation; neither a hit nor its count establishes argument omission. The collector does not evaluate defaults, retain call-site argument presence, or add omission-specific obligations. Defaults that raise before entry yield no target entry evidence and preserve Ruby's exception. Defaults calling another selected method can contribute that other method's own entry observations within scope. Non-primitive effective values make collection incomplete; primitive values outside a declared domain invalidate the entire tuple. Rest, keyword-rest, forwarding, and explicit block parameters remain unsupported.

Method identity is the selected owner's directly defined public Ruby instance method, bound before observation begins. Calls through aliases of that same definition count. A subclass override contributes only when it executes the selected definition through `super`; a distinct override does not count merely because its method name matches. Aliased or inherited target declarations, unsupported signatures, and unresolved/autoloaded target owners fail binding. Two target names resolving to the same owner and method fail with `duplicate_binding`. Observed redefinition invalidates collection. Removing, rebinding, or replacing the selected constant path with an autoload at the end of collection produces `target_binding_changed`; previously observed hits remain, and unobserved obligations become unknown. Constant bindings must remain stable during the run; transient changes restored before final inspection are outside this guarantee. Supported runtime compatibility is CRuby 3.3, 3.4, and 4.0 with Minitest >= 5.26.2 and < 5.28.0, requiring matching package/runtime major and minor versions.

Before collection, the adapter atomically replaces any previous report with a marker for the new run, `completion: "running"`, `integrity: false`, and `tests_passed: null`. Finalization replaces it with the new run's final report. An interrupted run cannot leave an old successful report presented as current evidence. A report-write failure fails the adapter run and prints a diagnostic; a leftover running marker remains insufficient evidence.

Missing input obligations are informational by default. Strict missing mode can make the process fail even when `tests_passed` is true, because that field preserves the original assertion result. Assertion failures remain failures in either mode; collector/configuration integrity failures also fail the invocation. Input hits and assertion results are separate evidence: 100% input coverage does not establish behavioral correctness.
