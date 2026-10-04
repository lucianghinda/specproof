# Pairwise partition coverage results

`pairwise-partitions-v1` plans category pairs from explicit complete, disjoint
integer partitions crossed with finite inputs. The scalar
`input-basics-v1` and finite-value `pairwise-finite-v1` criteria retain their
existing behavior. This criterion supports only `all_allowed: true`; forbidden
assignments and explicit partitions on finite-valued inputs are rejected.

The runnable [age-by-country example](../examples/pairwise_partitions/README.md)
uses age `0..120`, partitioned into minor `0...18` and adult `18..120`, crossed
with countries `"ro"` and `"de"`. The plan contains four category pairs. A
partition obligation serializes its inclusive category bounds, for example
`{ "kind": "partition", "name": "minor", "lower": "0", "upper": "17" }`.

On CRuby 4.0.1 with the prepared partition bundle, the initial example process
passed 1 test and 3 assertions, exercising 3/4 pairs. The missing pair was
minor/`"de"`. `specproof suggest` inferred `pairwise-partitions-v1` from the
checked report and returned the concrete call input `age: 0, country: "de"`
with strategy `greedy-partition-pairwise-v1`. The separate complete process
passed 2 tests and 4 assertions, exercising 4/4 pairs. Both processes completed
with intact reports and `tests_passed: true`.

The category report and suggested input establish only category membership for
the declared values. The lower endpoint is a concrete representative; it does
not establish boundary-value coverage or equivalent behavior throughout a
category. The requirement file supplies the expected result for the added
under-18 assertion. No output or behavioral rule is inferred from the plan or
suggestion.

## Verification

The complete core suite passed on CRuby 3.3.6, 3.4.7, and 4.0.1: 284 tests
and 1,440 assertions on each version. The optional RBS suite passed on each:
54 tests and 499 assertions. RBS signature validation also passed on all three.
No failures, errors, or skips occurred. Dependencies were reused from prepared
local bundles; the feature adds no dependencies.

Regression coverage includes category membership within one valid call,
independent exact-value scalar obligations, canonical category identities,
huge integer endpoints, invalid partition geometry and policies, unsupported
forbidden assignments and finite partitions, multi-pair suggestions, bounded
enumeration, and rejection of altered category identities in coverage reports.
RuboCop passed for 140 files. Syntax, packaged skill assets, and gem build
checks also passed (2 packaging/asset tests, 76 assertions).

The [installed agent exercise](evaluations/pairwise-partitions-skills.md)
records old-guidance and updated-guidance runs, unchanged fixture checks,
report tampering rejection, and hashes of the tested packaged library/skills.
