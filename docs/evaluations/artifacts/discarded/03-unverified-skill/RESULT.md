# Result

## Conclusion

Added the missing age-18 regression assertion and fixed `Registration#adult?` to
use the inclusive adult boundary (`age >= 18`), as required by
`requirements.md`. The age-18 assertion failed against the original method and
passed after the fix. The final fresh full-suite run passed and exercised all
six planned obligations.

## Changed files

- `registration.rb`: changed `age > 18` to `age >= 18`.
- `test/registration_test.rb`: added `assert_obligation(18, true)`. The shared
  assertion helper retains each candidate's SpecProof obligation ID and cites
  `requirements.md`'s `age >= 18 is adult` rule in its failure message.
- `RESULT.md`: this execution record.

## Evidence

Working directory: `/private/tmp/specproof-agent-evaluations/with-skill-1/03-age-boundary/ownchanges`.
Installed runtime: Ruby 4.0.1, SpecProof 0.1.0, Minitest 5.27.0.
The complete test inventory is `test/test_helper.rb` and
`test/registration_test.rb`.

Initial contract check:

```text
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/registration.rb --format json
```

Result: schema 1, SpecProof 0.1.0, no errors or findings, contract digest
`e106856acde285ff31e9932f715d6c66d43ac99fe734d379323b699c3ffee760`.

Initial plan command:

```text
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/registration.rb --format json
```

It returned six obligations for ages 0, 1, 17, 18, 119, and 120. Age 18 is
obligation `45de5269bc88dde762b107ae9288b0053e72afc55e63515d55a5483e05810b2a`,
the adult partition's lower endpoint, sourced at
`specifications/registration.rb:4`. The other IDs and sources are available in
the current plan and generated coverage report.

After adding only the regression assertion, the old implementation failed:

```text
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/registration_test.rb
```

Result: exit 1; `RegistrationTest#test_adult_upper_boundary_candidates`
failed at age 18 with expected `true`, actual `false`. The failure message
included the age-18 obligation ID and the requirement citation. Because the
assertion stopped that test method, the interim report showed 4/6 obligations
exercised; this was not used as final coverage evidence.

After the implementation fix, refreshed the plan using the same `specproof
plan ... --format json` command above. Its digest remained
`e106856acde285ff31e9932f715d6c66d43ac99fe734d379323b699c3ffee760` and it
still contained the same six obligations.

Fresh full-suite command, run after the final edit:

```text
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/registration_test.rb
```

Result: exit 0; 2 runs, 12 assertions, 0 failures, 0 errors, 0 skips. The run
summary ID `ab368b0a-947e-40e0-b0ee-94b8d0b947af` matched
`tmp/specproof.json`. The generated schema-1 coverage report has the matching
contract digest, `criterion: input-basics-v1`, no test filter, `completion:
completed`, `integrity: true`, `tests_passed: true`, no errors or incomplete
reasons, zero unknown/missing obligations, no outside-domain values, and all
six obligations marked `exercised` with one hit each.

## Limits

SpecProof establishes that the planned input values were observed during this
fresh run; expected behavior comes from the independent `requirements.md`
rule and the Minitest assertions. No material uncertainty remains for this
fixture's stated adult boundary.
