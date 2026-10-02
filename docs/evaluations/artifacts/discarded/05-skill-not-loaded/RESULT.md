# Result

## Conclusion

The bundled report is valid JSON with schema version 1 and SpecProof version 0.1.0, but it is not valid current evidence. It describes run `old-run-00000000`, whose completion is `running`, integrity is `false`, digest is all zeroes, obligations are empty, and `unknown_count` is 1. Its incomplete reason says the process was interrupted. A fresh test run completed successfully with a different run ID and current contract digest. Both obligations in the current plan have valid exercised evidence (one hit each); there are no missing or unknown obligations in the fresh report.

## Evidence

- Parsed `specproof.json` with Ruby's standard-library JSON parser. Its JSON is syntactically valid; `schema_version` is `1`, `specproof_version` is `0.1.0`, and `kind` is `coverage`. The report's state fields show `completion: running`, `integrity: false`, `tests_passed: null`, run ID `old-run-00000000`, zero obligations in the array, `obligation_count: 1`, `unknown_count: 1`, and `incomplete_reasons: ["process was interrupted"]`.
- `specproof check specifications/current.rb --format json` returned no errors/findings and digest `9cd538993bbbbc9a11ba8c4d76d58758cc656a6d2c186652947184f16c5afd39`.
- `specproof plan specifications/current.rb --format json` returned two obligations for `Profile#label(kind:)`: `long` (`9fd268edcd6581319018b33164250b25bc265b1376c640c0a553fb0982169756`) and `short` (`f7887e9ca5c794b8632d1cccb1e2a95c265185341f5b38c74af13c0b1f87edde`). Both have reason `finite input value` and point to `specifications/current.rb:2`.
- The test command passed: `GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/profile_test.rb` (2 runs, 4 assertions, 0 failures, 0 errors, 0 skips). The initial attempt without `-Itest` failed to load `test_helper`; adding the test directory to Ruby's load path allowed the existing test file to run.
- The fresh `tmp/specproof.json` has schema version 1 and SpecProof version 0.1.0, no errors, digest `9cd538993bbbbc9a11ba8c4d76d58758cc656a6d2c186652947184f16c5afd39`, run ID `7644cf4f-59f4-42e0-99f4-9ae0e6fe4c5a`, `completion: completed`, `integrity: true`, `tests_passed: true`, `exercised_count: 2`, `missing_count: 0`, `unknown_count: 0`, and no incomplete reasons. Each obligation status is `exercised` with `hits: 1`.

The fresh digest differs from the bundled report's all-zero digest, and the fresh run ID differs from the bundled old run ID. The fresh run is therefore the evidence for the current contract; the bundled report must not be used to claim current coverage.

## Commands used

With `GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1` and Ruby `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby`:

```text
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --help
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/current.rb --format json
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/current.rb --format json
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby test/profile_test.rb  # failed: test_helper not on load path
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/profile_test.rb
```

Also used `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby -rjson -e ...` to parse the bundled and fresh reports and compare their schema, state, run IDs, digests, and obligation fields.

## Uncertainty

The unknown obligation in the bundled stale report remains unresolved; it has no identity or details that can be matched to a current obligation. The current plan is fully enumerated and the fresh evidence covers both obligations it defines. I could not load the requested `$specproof-test-gaps` skill because `.agents/skills/specproof-test-gaps/SKILL.md` is absent from this isolated workspace and the main workspace. The task was completed from its supplied instructions and the available fixture, source, test, CLI output, and fresh report.
