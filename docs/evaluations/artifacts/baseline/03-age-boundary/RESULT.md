# Result

Added the missing age-18 boundary assertion and changed `Registration#adult?`
to accept age 18. The shared assertion helper resolves each age to its
SpecProof obligation and includes that obligation ID plus the checked source
method (`registration.rb#adult?`) in the assertion message.

## Evidence

- Check command:
  `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check /private/tmp/specproof-agent-evaluations/baseline/03-age-boundary/specifications/registration.rb`
  Result: no specification findings.
- Plan command:
  `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan /private/tmp/specproof-agent-evaluations/baseline/03-age-boundary/specifications/registration.rb`
  Result: six candidates (0, 1, 17, 18, 119, and 120); 18 is the adult lower
  endpoint.
- Initial baseline command,
  `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby test/registration_test.rb`,
  could not load `test_helper`; adding `-Itest` fixed the test load path.
- Before the edit, the corrected command
  `env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -Itest test/registration_test.rb`
  passed 2 tests and 10 assertions; SpecProof reported 5/6 obligations
  exercised.
- After the edit, a fresh invocation of that corrected command passed 2 tests
  and 12 assertions with 0 failures, 0 errors, and 0 skips. SpecProof reported
  6/6 obligations exercised.

All Ruby invocations used the installed validation gem environment shown in
the commands above.

## Uncertainty

The task describes `test/registration_test.rb` as the suite. I ran that full
suite; no other test files were invoked.
