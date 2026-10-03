# Scoped adoption result

SpecProof 0.1.0 evaluated `Delivery#save` with the selected RBS target. The contract digest is `b4cb79df5262530d531928bff713d17335b577f70d9bbf7e33b2dea5d2721b7e`.

The clean check reported zero findings and zero errors. The `input-basics-v1` plan contains two obligations, both sourced from `sig/delivery.rbs:2`:

| Input/value | Obligation ID | Evidence |
| --- | --- | --- |
| `expedited = false` | `c8217fbcb7a4aa45379837eb3895d9167d5c3ea884a126d64a030bea7a4379a3` | Existing `test_standard_delivery_preserves_payload` calls `save(payload)`; Ruby's default makes the effective input `false`, and its `:standard` assertion matches `requirements.md:3`. |
| `expedited = true` | `3a1322e30fee046de0c08c2dd7169a4421a1ca2d6cddaceef08338d037e988c4` | Added `test_expedited_delivery_is_express_and_preserves_payload`; it asserts `:express` per `requirements.md:3` and payload identity per `requirements.md:2`. |

Scope is `analyzed_inputs`: only `expedited` is analyzed. `payload` is explicitly excluded at `specification.rb:4` because payload contents are outside the requested input coverage scope. The final fresh report has run ID `2a7e33e1-a62b-4c7e-81b6-320e33806d2b`, 2 obligations, 2 exercised (one hit each), 0 missing, 0 unknown, no outside-domain inputs, `completion: completed`, `integrity: true`, and `tests_passed: true`. It records target `Delivery#save`, the specification and RBS declaration sources, no run filters, and `arguments: []`.

Commands were run through the supplied Ruby capture helper:

- `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby capture.rb tool --version` — exit 0; SpecProof 0.1.0.
- `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby capture.rb tool check specification.rb --rbs sig/delivery.rbs --target 'Delivery#save' --format json` — exit 0; no findings or errors.
- `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby capture.rb tool plan specification.rb --rbs sig/delivery.rbs --target 'Delivery#save' --format json` — exit 0; two obligations above.
- `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby capture.rb test` with the original one-test file restored temporarily — run ID `daaad776-714c-4d45-adb3-91668cceb567`; 1 run, 2 assertions, no test failures/errors/skips. The report exercised false (1/2) and missed true; adapter policy made the command exit 1 because an obligation was missing. This is preserved as `scoped-baseline-coverage.json`.
- `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby capture.rb test` after restoring the final tests — run ID `2a7e33e1-a62b-4c7e-81b6-320e33806d2b`; exit 0; 2 runs, 4 assertions, no failures/errors/skips, 2/2 obligations exercised.

`baseline-coverage.json` preserves the first pre-test-edit run unchanged; it exited 1 and is incomplete because `specification.rb` did not yet exist, so it is not the valid scoped baseline. `scoped-baseline-coverage.json` is the corrected baseline with the specification present and original assertions restored. `initial-final-coverage.json` preserves the first passing final report (run ID `ce88c6a1-7786-4b2a-8088-225d2cc9ded8`) before the baseline correction. `final-coverage.json` is the latest fresh passing report. Captured command statuses and streams are under `evidence/`.

The results establish input-obligation exercise and the asserted outcomes in this fixture. They do not establish general payload-content behavior: `payload` is excluded from input analysis, and the two identity assertions cover only their specific Hash examples. The conditional `:notified` requirement in `requirements.md:4` is outside this method's supplied signature because it has no `notify` parameter; no notification behavior was checked. Effective-value collection also cannot distinguish omission from explicitly passing `false`.
