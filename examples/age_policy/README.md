# An input gap that hides a boundary defect

For this demonstration the accepted domain is integer ages `0..120`, and the
intended rule is that an age of **18 or greater is adult**. That independent
rule supplies the assertion oracle. The input specification partitions ages
into minor (`0...18`) and adult (`18..120`); it does not declare return values.

Run these commands from the gem root with its development bundle and a
supported Minitest installation (the development bundle selects 5.26.2):

```sh
bundle exec specproof check examples/age_policy/specification.rb --format json
bundle exec specproof plan examples/age_policy/specification.rb --format json
bundle exec ruby examples/age_policy/run.rb missing
bundle exec ruby examples/age_policy/run.rb regression
bundle exec ruby examples/age_policy/run.rb correct
```

The plan proposes `0`, `1`, `17`, `18`, `119`, and `120`. The `missing` mode
runs the existing five non-boundary assertions against the faulty `age > 18`
implementation. The tests pass; the report identifies age 18 as unobserved.

The `regression` mode adds the explicit intended assertion for age 18. This
command intentionally exits unsuccessfully: its assertion fails against the
same faulty implementation. Age 18 is now exercised even though the behavior
is wrong, illustrating why input coverage and correctness are separate.

The `correct` mode runs all six assertions against `age >= 18`. The tests
pass and all six obligations are exercised. These are separate subprocesses,
so their alternative `AgePolicy` definitions never coexist in one run.

Each mode writes a fresh report to `tmp/age-policy-MODE.json`. An optional
second argument selects another report path. Match its `run_id` with the
printed summary and compare its contract digest with the current plan.
`SPECPROOF_STRICT=1` enables missing-obligation failure for this example;
it leaves the underlying assertion result visible in `tests_passed`.

The deterministic acceptance tests in `test/workflow_test.rb` execute this
same runner, including the intentionally failing mode, as subprocesses.
