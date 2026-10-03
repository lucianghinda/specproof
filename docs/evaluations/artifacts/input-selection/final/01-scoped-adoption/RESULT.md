# SpecProof evaluation result

## Contract and scope

- Target: `Delivery#save`.
- Contract digest: `b4cb79df5262530d531928bff713d17335b577f70d9bbf7e33b2dea5d2721b7e`.
- Check: no errors or findings. Plan: criterion `input-basics-v1`, two obligations.
- Analyzed input: `expedited`, imported as finite booleans from `sig/delivery.rbs:2`; no duplicate DSL boolean declaration.
- Excluded input: `payload`, reason: “Payload contents are outside the requested expedited option coverage” (`specification.rb:4`).
- Candidates: `false` (obligation `c8217fbcb7a4aa45379837eb3895d9167d5c3ea884a126d64a030bea7a4379a3`) and `true` (obligation `3a1322e30fee046de0c08c2dd7169a4421a1ca2d6cddaceef08338d037e988c4`), both from RBS line 2.

## Coverage evidence

Baseline is preserved in `baseline-coverage.json`: run ID `2b7c1142-37db-4c58-9de0-cfe5d58bd2ce`, same digest and input scope, completed with intact report and `tests_passed: true`; one of two obligations was exercised (`false`), while `true` was missing. The test process exited 1 because the adapter was configured with `fail_on_missing: true`.

The prior final report is preserved in `final-coverage-before-provenance-correction.json`. After correcting the assertion source citation to `requirements.md:3`, fresh evidence is preserved in `final-coverage.json`: run ID `9e7ce3f2-becd-486e-8846-a58a8c0cdae7`, same digest and scope, completed with `integrity: true`, `tests_passed: true`, 2/2 exercised, zero missing, unknown, outside-domain, or incomplete entries. The final suite ran 2 tests and 3 assertions with no failures or errors.

The new assertion checks `:express` for `expedited: true` and cites obligation `3a1322e30fee046de0c08c2dd7169a4421a1ca2d6cddaceef08338d037e988c4` and the independent rule in `requirements.md:3`. The pre-existing test still asserts that the payload object is returned unchanged and that the default `false` case uses `:standard`.

## Captured SpecProof/test commands

All SpecProof and test commands used `ruby capture.rb`; stdout, stderr, and exit status are in `evidence/`.

- `ruby capture.rb tool check specification.rb --rbs sig/delivery.rbs --target 'Delivery#save' --format json` — exit 0; no findings.
- `ruby capture.rb tool plan specification.rb --rbs sig/delivery.rbs --target 'Delivery#save' --format json` — exit 0; two boolean candidates.
- Baseline `ruby capture.rb test` — exit 1; 1 test, 2 assertions, zero test failures/errors; one obligation missing.
- Final `ruby capture.rb test` — exit 0; 2 tests, 3 assertions, zero failures/errors; both obligations exercised.

## Limits

This establishes input-obligation exercise only for effective `expedited` values `false` and `true`. It does not measure payload contents, argument presence/omission, output correctness generally, interactions, or complete method correctness. Payload unchanged is asserted in the pre-existing example but its input is excluded from SpecProof coverage. The signature has no `notify` input, so the conditional `:notified` rule in `requirements.md` has no corresponding input scenario in this task's supplied target signature and was not measured or asserted here. The suite uses the supplied single test file through `run.rb`, not a larger application-wide suite.
