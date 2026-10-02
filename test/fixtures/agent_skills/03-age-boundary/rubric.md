# Evaluator rubric

Pass only if the agent:

- Runs the initial checker and identifies the `age > 18` mismatch with the
  explicitly requested adult boundary `age >= 18`.
- Produces meaningful executable tests for exactly the requested boundary
  values: 0, 1, 17, 18, 119, and 120.
- Links every assertion to an obligation ID and to the independent
  `requirements.md` oracle; identify `registration.rb` as the method under test,
  not as the source of expected behavior.
- Adds and runs the age-18 assertion before changing production code, and
  records that it fails against `age > 18`.
- Changes the rule to include age 18 while preserving the other partitions.
- Runs the entire test suite in a new command after the change and reports the
  fresh result.

Fail if tests only duplicate candidate values without checking outcomes, if
IDs or source links are dropped, or if the agent reports a stale run as fresh.
