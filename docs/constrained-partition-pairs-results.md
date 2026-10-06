# Constrained partition pairs: verification

The [example](../examples/constrained_partition_pairs/README.md) declares
`forbid age: in_partition(:minor), account: "business"`. Filtering complete
category assignments leaves six allowed tuples, eleven required pairs, and
one excluded pair. Its three baseline calls cover nine pairs. Two suggested
calls, with independent requirement-based assertions, bring coverage to eleven
of eleven.

Luna subagents implemented the core, integration tests and documentation.
Separate specification and code reviews found no remaining code issues.
Review corrected missing restriction provenance and clarified historical
documentation. Native argument validation retains exact finite types,
including `nil` and `false`; integer restrictions require explicit selectors.

Verification on CRuby 3.3.6, 3.4.7 and 4.0.1 passed on each version:

| Suite | Tests | Assertions |
| --- | ---: | ---: |
| Core | 303 | 1,579 |
| Optional RBS | 55 | 509 |

RBS signature validation, RuboCop (144 files), syntax checks, packaged skill
checks and gem building passed. A final reuse of the memoized allowed
assignments was checked with 50 focused tests and 240 assertions on Ruby 4.

A separate exhaustive oracle checked all 256 forbidden subsets of an
eight-tuple category space: two integer inputs sharing partition names and
a finite input containing `nil` and `false`. Allowed assignments, required
pairs, excluded pairs and acceptance of 8,192 native tuples matched independent
expected results, including the entirely forbidden space.

A Luna agent followed the updated test-gap skill against a scratch copy of
the example. It obtained the two legal suggestions from the 9/11 baseline,
used the separate requirements to justify expected outputs, and verified the
complete run: two tests, five assertions and 11/11 feasible pairs exercised.
The excluded minor/business pair remained outside the denominator. This was
a source-checkout guidance exercise, not a fresh installed-gem evaluation.

The implementation reuses existing coverage accounting, report validation and
suggestion selection. No dependencies were added. Restrictions select whole
integer partitions or exact finite values; arbitrary predicates and partial
integer restrictions remain unsupported. Existing enumeration limits apply
before restrictions reduce the space.
