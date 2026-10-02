# Stale report evaluation

The bundled `specproof.json` is not valid evidence for the current suite. Its
schema and kind identify a coverage report, but it is an old, incomplete
running report: `run_id` is `old-run-00000000`, its contract digest is all
zeroes, `unknown_count` is 1, `completion` is `running`, `integrity` is false,
and `tests_passed` is null. It has no obligation entries, so the unknown
obligation cannot be mapped to a current obligation and remains unresolved.
The zero `missing_count` and empty `missing` array do not establish coverage.

Fresh checks report SpecProof 0.1.0, no specification findings or errors, and
contract digest
`9cd538993bbbbc9a11ba8c4d76d58758cc656a6d2c186652947184f16c5afd39` for
`specifications/current.rb`. The fresh plan has two obligations for
`Profile#label(kind)`: `long` (ID
`9fd268edcd6581319018b33164250b25bc265b1376c640c0a553fb0982169756`) and
`short` (ID
`f7887e9ca5c794b8632d1cccb1e2a95c265185341f5b38c74af13c0b1f87edde`).

The actual test command passed: 2 runs, 4 assertions, no failures or errors.
Its fresh report has run ID `bc176d9b-ecf9-4652-bff7-c4466c01a50c`, matching
the run summary emitted by that invocation. The report digest matches the
fresh plan; schema version is 1, kind is `coverage`, criterion is
`input-basics-v1`, scope has no argument filter or exclusions, completion is
`completed`, integrity and `tests_passed` are true, and errors and incomplete
reasons are empty. Both planned IDs appear as `exercised` with one hit each;
`missing_count` and `unknown_count` are zero and `outside_domain` is empty.
The existing tests assert the expected label for each input, so both current
obligations have valid evidence in this fresh run: `short` asserts
`"Profile"`, and `long` asserts `"A longer profile label"`.

## Commands and provenance

Skill used: `/private/tmp/specproof-agent-evaluations/release-skill-2/05-stale-report/.agents/skills/specproof-test-gaps/SKILL.md`

Skill SHA-256: `7442589ae052ac090b7ad1edd8e5c350abee1f18577da1657324b1e081a42e7a`

Referenced usage: `/private/tmp/specproof-agent-evaluations/release-skill-2/05-stale-report/.agents/skills/specproof-test-gaps/references/usage.md`

Usage SHA-256: `cdb33532404cddb42c0c93b0f6a77a8ef09eb7ca9e488ec364d550dbfa940a0d`

All commands ran from `/private/tmp/specproof-agent-evaluations/release-skill-2/05-stale-report` with `GEM_HOME=/private/tmp/specproof-validation-gems`, `GEM_PATH=/private/tmp/specproof-validation-gems`, `MT_NO_PLUGINS=1`, and Ruby `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby`:

```text
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --version
=> SpecProof 0.1.0

env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/current.rb --format json
=> errors: []; findings: []; contract_digest: 9cd538993bbbbc9a11ba8c4d76d58758cc656a6d2c186652947184f16c5afd39

env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/current.rb --format json
=> 2 obligations listed above; contract_digest matches check.

env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/profile_test.rb
=> exit 0; 2 runs, 4 assertions, 0 failures, 0 errors, 0 skips
=> SpecProof coverage run bc176d9b-ecf9-4652-bff7-c4466c01a50c: 2/2 obligations exercised (completed)
```

The test invocation generated `tmp/specproof.json`; no source, specification,
or test files were changed. This workspace contains one test file and no
project test-runner configuration, so the executed command is the available
suite here. As the usage reference notes, report scope cannot attest which
test files the caller loaded. The identity and intended meaning of the old
report's unknown obligation remain uncertain because the stale report contains
no obligation entry for it; it is kept unresolved rather than inferred from
the current plan.
