# Result

SpecProof's plan for `Registration#adult?` lists `18` as the adult lower endpoint. Before the regression assertion was added, the test file covered `0`, `1`, `17`, `119`, and `120`, leaving that planned endpoint unexercised.

## Changes

- `registration.rb`: changed the adult threshold from `age > 18` to `age >= 18`.
- `test/registration_test.rb`: added the age-18 adult assertion. Boundary assertions continue to resolve their SpecProof obligation and include its ID and the source rule (`requirements.md`: adults are ages 18 through 120 inclusive) in assertion diagnostics.

## Commands and outcomes

- `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/registration.rb` — listed candidates `0, 1, 17, 18, 119, 120`; identified `18` as the adult lower endpoint.
- `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/registration_test.rb` — passed: 2 runs, 12 assertions, 0 failures, 0 errors, 0 skips. This was run as a fresh command after the edits.
- `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/registration.rb` — no specification findings; coverage run reported 6/6 obligations exercised.

## Uncertainties

The fixture defines the accepted domain as 0 through 120, but the task only required fixing the adult boundary; this change does not add runtime validation for out-of-domain inputs.
