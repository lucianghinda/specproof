# SpecProof evaluation

## Recommendation

Ask the product owner which scores `CandidateCode#valid?` should accept before writing a regression test. The only stated requirement is that scores are integers from 0 through 100, inclusive; it does not define the validity predicate. The candidate's `even?` implementation is explicitly experimental and must not be used as the expected result.

SpecProof's plan is useful for selecting boundary cases: `0`, `1`, `99`, and `100` represent the endpoints and their adjacent in-range values. Once the expected behavior is specified, a regression test should assert the owner-confirmed outcomes for those relevant cases. At present, no honest pass/fail assertion can be chosen, so do not add an assertionless test or infer that parity determines validity.

## Commands and results

Environment prefix for all commands:

```text
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1
```

CLI help:

```text
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --help
```

Result: available commands are `--version`, `check`, `plan`, and `skills export`; `check` and `plan` accept a Ruby specification path and optional `--format human|json`.

Check:

```text
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check /private/tmp/specproof-agent-evaluations/baseline-v2/04-no-oracle/specifications/candidate.rb
```

Result: `No specification findings.`

Plan:

```text
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan /private/tmp/specproof-agent-evaluations/baseline-v2/04-no-oracle/specifications/candidate.rb
```

Result: target `CandidateCode#valid? / score`, criterion `input-basics-v1`, candidates `0, 1, 99, 100`; labels identify lower endpoint, lower neighbor, upper neighbor, and upper endpoint.

## Limits and uncertainty

The check result means the CLI emitted no specification findings; it does not establish the intended valid-score rule. The plan supplies useful input candidates but does not supply expected values. No test suite was present in the assigned fixture, so no application tests were run.
