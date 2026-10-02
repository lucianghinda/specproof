# Result

## Instructions and provenance

- Task: `TASK.md` in this workspace.
- Skill read: `/private/tmp/specproof-agent-evaluations/release-skill-2/03-age-boundary/.agents/skills/specproof-test-gaps/SKILL.md`
- Skill SHA-256: `7442589ae052ac090b7ad1edd8e5c350abee1f18577da1657324b1e081a42e7a`
- Referenced usage guide read: `/private/tmp/specproof-agent-evaluations/release-skill-2/03-age-boundary/.agents/skills/specproof-test-gaps/references/usage.md`
- Usage guide SHA-256: `cdb33532404cddb42c0c93b0f6a77a8ef09eb7ca9e488ec364d550dbfa940a0d`
- Runtime: SpecProof `0.1.0`; CRuby `4.0.1`; Minitest adapter report says schema `1`, criterion `input-basics-v1`.

## SpecProof discovery

Executed the real CLI with the supplied isolated gem environment:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --version
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/registration.rb --format json
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/registration.rb --format json
```

Version reported `SpecProof 0.1.0`. Check returned no errors or findings and contract digest `e106856acde285ff31e9932f715d6c66d43ac99fe734d379323b699c3ffee760`. The plan identified the missing age-18 adult lower endpoint:

- Obligation ID: `45de5269bc88dde762b107ae9288b0053e72afc55e63515d55a5483e05810b2a`
- Value: `age = 18`
- Source: `specifications/registration.rb:4` (`partition :adult, range: 18..120`)
- Independent expected result: `requirements.md` states adults are ages 18 through 120 inclusive.

## Regression and fix

Added age 18 to the existing adult boundary test via `assert_obligation(18, true)`. The helper looks up and includes the stable SpecProof ID and cites `requirements.md (age >= 18 is adult)` in the assertion failure message.

Before changing the implementation, ran:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/registration_test.rb
```

It failed at age 18 as expected: expected `true`, actual `false`; the failure named obligation `45de5269bc88dde762b107ae9288b0053e72afc55e63515d55a5483e05810b2a` and the requirement citation. The run had 2 tests, 8 assertions, 1 failure, and 0 errors. The old-method failure report was incomplete because the failing assertion stopped the remaining assertions in that test; it is retained here only as red regression evidence.

Changed `Registration#adult?` from `age > 18` to `age >= 18`, directly matching the stated requirement.

## Fresh full-suite evidence

After the final edit, reran the available full suite in a separate process using the same command:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/registration_test.rb
```

Result: 2 tests, 12 assertions, 0 failures, 0 errors, 0 skips. The invocation emitted run ID `bc9a3c59-2f85-4dea-8b0c-5c0331b92fa1` and reported 6/6 obligations exercised.

Inspected the generated `tmp/specproof.json` and a fresh `specproof plan` report after the suite. The coverage report has schema 1, kind `coverage`, criterion `input-basics-v1`, matching contract digest `e106856acde285ff31e9932f715d6c66d43ac99fe734d379323b699c3ffee760`, and the same run ID emitted by the final invocation. Scope has empty arguments, null filter and exclude; completion is `completed`; integrity and tests_passed are true; errors, incomplete reasons, missing, and outside-domain entries are empty; unknown and missing counts are zero. All six plan IDs are present as `exercised` with one hit each, including the age-18 obligation above.

## Changes and uncertainty

- `registration.rb`: fixed the adult lower boundary to include age 18.
- `test/registration_test.rb`: added executable age-18 regression evidence through the existing obligation-aware assertion helper.
- `RESULT.md`: recorded skill/reference hashes, commands, outcomes, and coverage provenance.

Uncertainty: the isolated fixture has one Minitest test file and no separate aggregate task was present in the workspace; `ruby -Itest test/registration_test.rb` ran the complete available suite. The workspace has no Git metadata, so changes could not be recorded with Git status/diff.
