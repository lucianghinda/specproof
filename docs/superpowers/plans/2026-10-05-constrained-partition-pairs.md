# Constrained partition pairs

Implement explicit whole-partition restrictions for `pairwise-partitions-v1`.

```ruby
combinations :age, :account, :country do
  forbid age: in_partition(:minor), account: "business"
end
```

`PartitionReference` is an immutable named selector, distinct from a literal Symbol and from a bounded `PartitionLevel`. Its canonical report encoding is `{kind: "partition_reference", name: "minor"}`. Integer range inputs require these selectors in restrictions; finite inputs continue to require exact primitive values. Invalid or unknown references are configuration errors.

Enumerate within existing limits, filter full category assignments, and derive required and excluded pairs from feasible completions. Match runtime native values to their categories before applying restrictions. Forbidden calls contribute no coverage. Suggestions choose only allowed assignments and use existing lower-endpoint representatives. Empty feasible spaces retain the existing `unsatisfiable_combinations` finding.

Implementation lanes:

1. Core model, DSL, validation, enumeration, report encoding, signatures and planner tests.
2. Suggestion preflight, runtime/report/suggestion integration tests and stale evidence checks.
3. README, report contract, example and both agent skills.
4. Independent review, integration fixes, full core/RBS tests, signatures, lint and packaging checks; commit on the feature branch.

Acceptance evidence: the registration example has six allowed full tuples, eleven required pairs and one excluded pair. Three initial calls cover nine pairs; two legal suggestions cover the remaining pairs. Exercise indirect exclusions, three-input restrictions, unsatisfiable groups, invalid selectors, canonical digests and compatibility with unrestricted partitions and finite combinations.

No arbitrary predicates, partial integer restrictions, new dependencies or automatic merge.
