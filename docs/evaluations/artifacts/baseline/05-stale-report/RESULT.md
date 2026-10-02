# Stale report evaluation

The bundled `specproof.json` is valid JSON and has schema version 1, but it is not usable as current evidence. It describes `old-run-00000000`, has an all-zero contract digest, reports `completion: "running"`, `integrity: false`, `tests_passed: null`, and has no obligation records despite `obligation_count: 1` and `unknown_count: 1`. Its `incomplete_reasons` says the process was interrupted.

I ran the current specification and existing test suite. The `check` command reported no errors or findings. The `plan` command reported two current obligations under criterion `input-basics-v1`. Both commands returned contract digest `9cd538993bbbbc9a11ba8c4d76d58758cc656a6d2c186652947184f16c5afd39`. The fresh coverage report has that same digest and schema version 1, a new run ID `0182597d-c21b-45e6-bc0a-8dd0b4ef4087`, `completion: "completed"`, `integrity: true`, `tests_passed: true`, two exercised obligations, zero missing/unknown/not-observed obligations, and no incomplete reasons. The test run passed: 2 runs, 4 assertions, 0 failures, 0 errors, 0 skips.

Current obligations with valid evidence in the fresh run:

- `Profile#label(kind: :long)` — exercised once; obligation ID `9fd268edcd6581319018b33164250b25bc265b1376c640c0a553fb0982169756`.
- `Profile#label(kind: :short)` — exercised once; obligation ID `f7887e9ca5c794b8632d1cccb1e2a95c265185341f5b38c74af13c0b1f87edde`.

Unknowns: the old report's one unknown obligation has no identity or value in the bundled report, so it cannot be matched to a current obligation or resolved from that report. The fresh plan contains only the two obligations above and reports no unknown obligations. This conclusion is limited to `specifications/current.rb` and the existing `test/profile_test.rb` run.

Commands actually run (environment prefix shown on each command):

```text
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --help
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/current.rb --format json
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/current.rb --format json
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby test/profile_test.rb
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/profile_test.rb
```

The first test command exited 1 because `test_helper` was not on Ruby's load path. I reran it with `-Itest`; that command exited 0 and generated `tmp/specproof.json`, the fresh report summarized above. `specproof check` and `specproof plan` each exited 0.

Artifacts: `RESULT.md` records the evaluation; `tmp/specproof.json` is the fresh coverage report emitted by the test run. The bundled `specproof.json` was left unchanged.
