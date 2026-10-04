# Partition-based pairwise coverage

Implement the approved `pairwise-partitions-v1` criterion without changing existing criteria.

## Scope and contracts

- Integer group inputs require explicit partitions, `exhaustive: true`, `disjoint: true`, and checked complete/disjoint geometry. Finite inputs contribute singleton values; finite inputs with explicit partitions are rejected for this criterion.
- Only `all_allowed: true` is supported. Forbidden assignments are rejected for this criterion. Existing finite pairwise restrictions retain their semantics.
- New immutable `PartitionLevel(name:, lower:, upper:)` represents a normalized inclusive integer category. It implements `include?(value)` and `representative` (lower endpoint). Its value equality/hash include name and both bounds.
- `PartitionSpace` mirrors `CombinationSpace` (`pairs`, `excluded_pairs`, `allowed_count`, `sources`, `allowed?`, `allowed_assignments`). Assignments and pairs contain PartitionLevel objects or existing finite primitives. Actual calls are checked against native domains. Categories are never expanded into integer values.
- Category serialization via `Report.value` is `{kind: "partition", name: "minor", lower: "0", upper: "17"}`. Native finite values retain their current typed representation. Human output includes name and interval.
- Pair IDs include criterion and category identity/bounds. Declaration reordering is stable. Existing finite IDs and reports remain unchanged.
- Checker supports integer groups using PartitionSpace after ordinary input checks. Invalid geometry remains an explainable semantic finding. Missing policies/partitions, finite grouped partitions, or forbidden rules are configuration errors for the new criterion.
- Coverage matches category membership in one observed call; scalar/BVA coverage remains exact-value based. Never claim semantic equivalence or correct output from category coverage.
- Suggestions infer the supported criterion from the validated coverage report. Existing CLI `suggest` still rejects an explicit `--criterion`. CoverageReport accepts an optional criterion keyword defaulting to the existing finite criterion, and strictly verifies category identities/bounds along with all existing evidence/digest/scope checks.
- SuggestionResult gains criterion and strategy readers with legacy defaults. New criterion uses strategy `greedy-partition-pairwise-v1`; concrete suggestion inputs replace PartitionLevel with its representative. No assertion oracle is invented.
- Keep existing bounds: 10,000 assignments/pair rows, cumulative suggestion limits and 1,000,000 membership checks. Count categories before enumeration; large integer endpoints do not increase category cardinality.

## Work lanes

1. Core model/space/checker/planner/signatures and core tests.
2. Runtime coverage, plan and Minitest reports, CLI integration tests.
3. Checked suggestions/report validation and tests.
4. Documentation, runnable example, agent skill guidance (after interfaces settle).

Each lane owns its files. Use Luna agents, regression tests, independent specification review followed by quality review. No new dependencies. Root integrates and verifies before committing the feature branch.

## Acceptance evidence

Age 0..120 split into minor 0...18 and adult 18..120, crossed with countries ro/de, produces four obligations. Calls (16,ro), (30,ro), (30,de) leave minor/de; suggested input is (0,de). Boundary coverage is independently incomplete. Reject gaps, overlaps, missing policies, unsupported finite partitions and forbid clauses; reject tampered/stale category coverage reports. Verify singleton intervals, huge integer bounds, typed finite values, same-call matching, non-group inputs, unknown/incomplete evidence and deterministic ordering. Run core, optional RBS, signatures, lint, package checks and supported Ruby matrix.

## Completion

All implementation lanes and the independent specification/quality reviews are complete. The final criterion snapshot immutability fix also received review. Verification: 284 core tests / 1,440 assertions and 54 optional RBS tests / 499 assertions on Ruby 3.3.6, 3.4.7, and 4.0.1; signature validation on all three; 140 lint files clean; syntax, package, and skill-asset checks pass. See the results and installed agent exercise documents for reproducible usage and scoped evidence. The branch remains separate from main for review and subsequent integration.
