# Result

## Skill used

- Exact path: `/private/tmp/specproof-agent-evaluations/with-skill-1-retry/03-age-boundary/.agents/skills/specproof-test-gaps/SKILL.md`
- SHA256: `7442589ae052ac090b7ad1edd8e5c350abee1f18577da1657324b1e081a42e7a`
- Referenced usage read: `.agents/skills/specproof-test-gaps/references/usage.md`

## SpecProof inspection

Executed the installed SpecProof CLI against `specifications/registration.rb`:

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/registration.rb --format json
```

Outcome: `errors: []`, `findings: []`, contract digest `e106856acde285ff31e9932f715d6c66d43ac99fe734d379323b699c3ffee760`.

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/registration.rb --format json
```

Outcome: six input obligations for ages 0, 1, 17, 18, 119, and 120. Age 18 is obligation `45de5269bc88dde762b107ae9288b0053e72afc55e63515d55a5483e05810b2a`, sourced from `specifications/registration.rb:4` (`adult` partition lower endpoint).

## Changes

- `test/registration_test.rb`: added the age-18 assertion. Each assertion's failure message includes its looked-up SpecProof obligation ID and cites the matching source rule in `requirements.md:4`.
- `registration.rb`: changed the adult boundary from `age > 18` to `age >= 18`.
- `tmp/specproof.json`: generated fresh coverage report from the final full-suite run.
- `RESULT.md`: this execution record.

The new age-18 assertion was first run against the original implementation. It failed as expected: obligation `45de5269bc88dde762b107ae9288b0053e72afc55e63515d55a5483e05810b2a`, expected `true`, actual `false`.

## Final verification

Ran the full supported fixture suite in a fresh process after the final edit:

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/registration_test.rb
```

Outcome: 2 runs, 12 assertions, 0 failures, 0 errors, 0 skips. The invocation reported coverage run `53854681-160a-4226-98c7-11b48352ea97`, with all 6 obligations exercised.

The generated `tmp/specproof.json` matches the fresh plan digest and latest run ID. It reports schema 1, kind `coverage`, no test-name filter, `completion: completed`, `integrity: true`, `tests_passed: true`, no errors or incomplete reasons, zero missing or unknown obligations, and no outside-domain calls. All six obligations have status `exercised` and one hit each.

## Uncertainty

The fixture exposes one supported full-suite command, `ruby -Itest test/registration_test.rb`; no separate broader suite command is present in the fixture files. The fixture directory is not a Git repository, so Git status could not be used to enumerate changes.
