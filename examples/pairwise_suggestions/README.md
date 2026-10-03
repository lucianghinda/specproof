# Pairwise missing-pair suggestions

Run these commands from `gems/specproof` with its development bundle. Reports
and generated suggestion JSON go under the ignored `tmp/` directory. Each
runner command starts a new Ruby process and writes a fresh coverage report.

```sh
bundle exec ruby examples/pairwise_suggestions/run.rb delivery-baseline tmp/suggestion-delivery-baseline.json
bundle exec ruby -Ilib exe/specproof suggest examples/pairwise/specification.rb --report tmp/suggestion-delivery-baseline.json --format json > tmp/suggestion-delivery.json
bundle exec ruby examples/pairwise_suggestions/run.rb delivery-gap tmp/suggestion-delivery-gap.json
bundle exec ruby -Ilib exe/specproof suggest examples/pairwise/specification.rb --report tmp/suggestion-delivery-gap.json --format json > tmp/suggestion-after-gap.json
bundle exec ruby examples/pairwise_suggestions/run.rb delivery-corrected tmp/suggestion-delivery-corrected.json
bundle exec ruby examples/pairwise_suggestions/run.rb booleans-baseline tmp/suggestion-booleans-baseline.json
bundle exec ruby -Ilib exe/specproof suggest examples/pairwise_suggestions/three_boolean/specification.rb --report tmp/suggestion-booleans-baseline.json --format json > tmp/suggestion-booleans.json
bundle exec ruby examples/pairwise_suggestions/run.rb booleans-complete tmp/suggestion-booleans-complete.json
```

The DeliveryOptions declaration and [requirements](../pairwise/requirements.md)
come from the existing pairwise example. Its baseline tests pass while
exercising three of four pair obligations. The suggestion command returns an
allowed `expedited: true, notify: true` assignment and the stable ID it covers.
That row is a candidate only: the example's separate gap test asserts the
independent requirement that the notification result equals `notify`. The
assertion fails against the faulty implementation, even though its fresh
report has exercised all four pairs. The corrected implementation passes that
same assertion in a separate process and writes a different report.
Running `suggest` on the failing gap report is also valid: it returns no rows
because all pairs were reached, while preserving `source_tests_passed: false`.

For three booleans, the baseline observes only `false, false, false`, leaving
nine pair IDs missing. One full assignment in the suggestion covers multiple
missing pairs. The group requires no joint restrictions, and the independent
[requirements](three_boolean/requirements.md) define the expected result. The
suggestion output lists the deliberately excluded `context` input as
`unassigned_inputs`; callers must still provide it and satisfy its application
contract. The completion run uses the three remaining assignments from the
small four-row covering set and asserts the requirement for every call.

Never turn suggestion output directly into a test call with generated or
implementation-derived expected values. Compare the report with a fresh
pairwise plan: it must be completed and intact, with the current digest, exact
typed obligation denominator and scope, consistent counters and projections,
and no errors or unknown observations. A failed assertion result is accepted
and preserved. Filtered reports remain limited to their recorded scope. The
digest does not fingerprint implementation or tests, so run the suite again
after any such changes. The CLI validates the report before producing any
suggestions; oversized or inconsistent evidence yields an error without
partial results.
