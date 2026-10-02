# Fresh coverage evaluation

The bundled `specproof.json` is stale and does not establish current coverage. A fresh full test-file run completed successfully and produced valid coverage evidence for both current obligations.

## Skill used

- Exact skill path: `/private/tmp/specproof-agent-evaluations/with-skill-1-retry/05-stale-report/.agents/skills/specproof-test-gaps/SKILL.md`
- SHA256: `7442589ae052ac090b7ad1edd8e5c350abee1f18577da1657324b1e081a42e7a`
- Read referenced usage: `.agents/skills/specproof-test-gaps/references/usage.md`

## Commands and outcomes

All SpecProof and Minitest commands used the supplied environment:

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/current.rb --format json
```

Exit 0. `errors` and `findings` were empty. Current contract digest: `9cd538993bbbbc9a11ba8c4d76d58758cc656a6d2c186652947184f16c5afd39`.

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/current.rb --format json
```

Exit 0. The plan has two obligations under criterion `input-basics-v1`, with the same digest as `check`:

| Obligation ID | Candidate | Source |
| --- | --- | --- |
| `9fd268edcd6581319018b33164250b25bc265b1376c640c0a553fb0982169756` | `Profile#label(kind: :long)` | `specifications/current.rb:2` |
| `f7887e9ca5c794b8632d1cccb1e2a95c265185341f5b38c74af13c0b1f87edde` | `Profile#label(kind: :short)` | `specifications/current.rb:2` |

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/profile_test.rb
```

Exit 0: 2 runs, 4 assertions, 0 failures, 0 errors, 0 skips. The run summary reported run ID `236c9d0e-665c-46a2-8494-c05154ec1dd1`, 2/2 obligations exercised, completed. The fresh report is `tmp/specproof.json`; it parses as schema 1, kind `coverage`, criterion `input-basics-v1`, matching contract digest and run ID. It has `completion: completed`, `integrity: true`, `tests_passed: true`, empty `errors` and `incomplete_reasons`, zero missing and unknown counts, and empty `outside_domain`. Both planned IDs appear with status `exercised` and `hits: 1`.

## Obligation evidence

- `9fd268edcd6581319018b33164250b25bc265b1376c640c0a553fb0982169756` (`:long`): valid current evidence. `ProfileTest#test_long_label` asserts the expected string `"A longer profile label"`; fresh report records one hit.
- `f7887e9ca5c794b8632d1cccb1e2a95c265185341f5b38c74af13c0b1f87edde` (`:short`): valid current evidence. `ProfileTest#test_short_label` asserts the expected string `"Profile"`; fresh report records one hit.

The target signature `Profile#label(kind)` matches the specification's target and input name. The assertions establish these two exact examples; SpecProof observes calls and does not prove correctness beyond them.

## Bundled report assessment

The bundled `specproof.json` has a zero digest that differs from the current digest, old run ID `old-run-00000000`, no obligation entries, `unknown_count: 1`, an interruption reason, `completion: running`, `integrity: false`, and `tests_passed: null`. Its `missing_count: 0` does not establish coverage. The fresh run supersedes it for current evidence.

## Changed and generated files

- Added `RESULT.md`.
- Fresh run generated `tmp/specproof.json`.
- No source, specification, or test files were changed.

## Uncertainty

No current obligation is unknown or unresolved in the fresh report. This result is limited to the two finite input obligations in the current specification and the observed assertions in this test run.
