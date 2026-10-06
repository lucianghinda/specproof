## [Unreleased]

- Prefer `allow_gaps` and `allow_overlaps` in input declarations, examples, and agent skills. Setting either to `false` requires that partition check; omitted options remain permissive. Keep `exhaustive` and `disjoint` as compatibility aliases with inverted booleans and preserve equivalent contract digests and obligation IDs.
- Suggest deterministic allowed group assignments for missing pairwise obligations from validated coverage reports, with explicit source run, scope, and unassigned parameters.
- Reject incompatible or incomplete suggestion evidence, preserve assertion failures, and update the packaged agent workflows.
- Add opt-in finite pairwise coverage with explicit allowed combinations, declarative forbidden assignments, feasible-pair planning, and joint-domain observation.
- Add `pairwise-partitions-v1` for category-pair planning over explicitly complete and non-overlapping integer partitions crossed with finite inputs.
- Support requirement-backed `forbid` assignments over whole integer partitions and finite values, deriving required and excluded category pairs from allowed completions.
- Add a runnable constrained partition-pairs example with excluded-pair reporting and allowed-assignment suggestions.
- Add a runnable age-by-country partition example with inferred-criterion suggestions and a requirement-backed category-gap assertion.
- Explain excluded pairs and missing interactions in CLI and Minitest reports; include runnable examples and packaged agent guidance.
- Import explicitly selected RBS scalar input types without a duplicate DSL declaration; require a behavioral refinement for unbounded integers and preserve honest limits for unsupported types.
- Import selected RBS string literals and finite literal unions as exact string scenarios; keep unrestricted `String` and unions with unsupported members as atomic errors.
- Add a compact RBS finite-string example showing a missing supported combination, a requirement-backed assertion, and a fresh complete report.
- Add an RBS-backed Registration example with a documented age-18 behavior rule, an eight-of-nine baseline gap, a failing boundary assertion, and a fresh corrected report.
- Update the bundled skills and report references for selected RBS targets, refinements, source scope, fresh report integrity, and the limits of coverage evidence.
- Observe effective scalar values for named optional positional and keyword parameters, with explicit report semantics and preserved Ruby default behavior.
- Retain a PStoreLogger scalar persistence pilot with complete filtered exercise and honest incomplete full-suite evidence on Hash inputs.
- Support correctly labeled Minitest 5.26.2 packages while preserving package/runtime mismatch rejection; use that published release in the development bundle.
- Record a real QualityGate input gap, an agent-added default assertion, paired focused-suite timings, and two rejected integration candidates.
- Documented input contracts, boundary planning, Minitest observation, and the bundled age and shipping examples.
- Added adoption and packaging workflow coverage for the optional runtime adapter.
- Recorded a small, reproducible baseline/instrumented age-policy timing comparison.
- Run CI on Ruby 3.3, 3.4, and 4.0.

## [0.1.0] - 2026-10-02

- Initial release
