# Minitest coverage report reference

Run the full test suite as a fresh process, for example:

```sh
bundle exec rake test
```

Prefer the repository's existing full-suite command when available. Do not
filter the suite when claiming total project coverage. The adapter measures
direct calls to supported methods during the original Minitest run. It does not
inspect assertions or replay tests. Unsupported signatures, collector errors,
and out-of-domain inputs cannot be counted as successful obligation evidence.

Parse the generated JSON and require all of the following before claiming the
current suite covered its plan:

- `schema_version` is `1` and `kind` is `"coverage"`.
- `criterion` is `"input-basics-v1"` and `contract_digest` matches a fresh
  `specproof plan PATH --format json` report for the same specifications.
- `run_id` is present and belongs to the latest full-suite execution; confirm
  it matches the run summary emitted by that invocation.
- `scope` describes the intended full run, with no test-name filter.
- `completion` is `"completed"`, `integrity` and `tests_passed` are `true`, and
  `errors` and `incomplete_reasons` are empty.
- `unknown_count` and `missing_count` are zero, `outside_domain` is empty, and
  every expected obligation ID appears with status `"exercised"` and a positive
  hit count.

The `missing` array lists candidates with no observed calls. `unknown_count`
and incomplete reports mean collection could not establish a result. Keep both
states open. Do not treat zero missing values in a stale report as current
evidence. Compare the fresh digest and run ID, and re-run the whole suite after
any source, specification, or test change.

When a newly added boundary assertion exposes a bug, preserve the red result
from the old implementation, fix the method using the independent requirement,
then run the full suite again. The final report should come from this new run;
retain the failing-run evidence in the task summary rather than presenting its
coverage report as the final one.
