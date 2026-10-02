# Evaluation result

The bundled `specproof.json` is stale and cannot establish current coverage. It parses as a schema 1 `coverage` report, but is only a running marker: `completion` is `running`, `integrity` is `false`, `tests_passed` is `null`, `run_id` is `old-run-00000000`, its all-zero contract digest differs from the current contract, `unknown_count` is 1, and `incomplete_reasons` contains `process was interrupted`. Its zero `missing_count` is not evidence that current obligations were exercised.

## Fresh run

Skill instructions and provenance:

- Skill: `/private/tmp/specproof-agent-evaluations/release-skill-1/05-stale-report/.agents/skills/specproof-test-gaps/SKILL.md`
  - SHA-256: `7442589ae052ac090b7ad1edd8e5c350abee1f18577da1657324b1e081a42e7a`
- Referenced usage: `/private/tmp/specproof-agent-evaluations/release-skill-1/05-stale-report/.agents/skills/specproof-test-gaps/references/usage.md`
  - SHA-256: `cdb33532404cddb42c0c93b0f6a77a8ef09eb7ca9e488ec364d550dbfa940a0d`

All commands ran from `/private/tmp/specproof-agent-evaluations/release-skill-1/05-stale-report` with `GEM_HOME=/private/tmp/specproof-validation-gems`, `GEM_PATH=/private/tmp/specproof-validation-gems`, `MT_NO_PLUGINS=1`, and Ruby `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby`.

- `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --version` → `SpecProof 0.1.0` (the report reference covers SpecProof 0.1.x).
- `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/current.rb --format json` → no errors or findings; contract digest `9cd538993bbbbc9a11ba8c4d76d58758cc656a6d2c186652947184f16c5afd39`.
- `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/current.rb --format json` → two obligations, `:long` ID `9fd268edcd6581319018b33164250b25bc265b1376c640c0a553fb0982169756` and `:short` ID `f7887e9ca5c794b8632d1cccb1e2a95c265185341f5b38c74af13c0b1f87edde`; both originate at `specifications/current.rb:2`.
- `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/profile_test.rb` → `2 runs, 4 assertions, 0 failures, 0 errors, 0 skips`; adapter summary: run `46cd4e04-fe8e-4dc5-b9b0-ee714cf28c2e`, `2/2 obligations exercised (completed)`.
- Parsed bundled and generated JSON with Ruby's standard-library JSON parser and compared report fields and obligation IDs/statuses to the fresh plan.

The generated `tmp/specproof.json` matches the fresh plan digest and run summary. It has schema 1, kind `coverage`, criterion `input-basics-v1`, `completion: completed`, `integrity: true`, `tests_passed: true`, empty errors/incomplete reasons/outside-domain values, `missing_count: 0`, `unknown_count: 0`, and both planned IDs with status `exercised` and one hit each. Scope has empty arguments and null filter/exclude. The only test file in this workspace is `test/profile_test.rb`; the command ran that file as the workspace's available suite.

## Current obligation evidence

Both current obligations have valid evidence in this fresh run. `ProfileTest#test_long_label` asserts `Profile.new.label(:long) == "A longer profile label"`, and `ProfileTest#test_short_label` asserts `Profile.new.label(:short) == "Profile"`; each assertion includes its corresponding obligation ID and source location. The test assertions passed, while the coverage report independently recorded one direct method-call hit per obligation.

This establishes observed calls and passing assertions for these two specified input values only. It does not establish behavior beyond the declared finite domain or broader application correctness. No current obligation remains unknown or missing.

## Changed files and uncertainty

- Added `RESULT.md`.
- Generated `tmp/specproof.json` from the fresh adapter run. The bundled stale `specproof.json`, specification, implementation, and tests were not edited.
- No uncertainty remains about the two planned obligations. Coverage scope is limited to the sole test file present in this assigned workspace and the two values declared by the current specification.
