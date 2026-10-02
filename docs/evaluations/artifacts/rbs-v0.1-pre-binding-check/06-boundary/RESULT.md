# Boundary evaluation result

## Inputs and oracle

Loaded `TASK.md`, `requirements.md`, `supplied-context.json`, `reports/baseline.json`, `run.rb`, the target implementation and tests, the RBS signature, and the input DSL. Explicitly loaded `.agents/skills/specproof-test-gaps/SKILL.md` and `references/usage.md`. The independent behavior oracle is `requirements.md`: eligibility is true exactly when age is at least 18 and consent is true. RBS was used only for input types, never as an expected-output oracle.

The missing baseline obligation was `f34bb1fa38998396c7ddf02a20ba326da6c30131d696dabee7e7f6acff06daa8`, `Registration#eligible?` at age 18 (adult lower endpoint). Baseline digest was `03501b28c964e6614a246f1520ecdb367e9d94f021ec3e7ea7b1dfc2f52dad3e`. Fresh `check` had no findings, and fresh `plan` retained the same digest and listed the age-18 obligation.

## Change and RED evidence

Added one meaningful age-18 assertion with consent true, citing the normative requirement and obligation ID in its failure message. All pre-existing assertions were preserved. Before changing the implementation, ran `REPORT_NAME=red.json ruby run.rb` through the supplied capture helper. The test failed at the new assertion (`1 runs, 4 assertions, 1 failures`), establishing RED against the prior `age > 18` implementation. The captured report and command record are `reports/red.json` and `logs/red-run.json`; red run ID: `99156b88-94ca-4551-a1f7-aaf9a6f562ae`.

Changed the implementation comparison from `age > 18` to `age >= 18`, matching the independently supplied threshold rule.

## Fresh final evidence

Ran a new process with `REPORT_NAME=final.json ruby run.rb` through the capture helper. The actual loaded command was Ruby 4.0.1 `run.rb` from this workspace; `run.rb` loads `test/registration_test.rb` and installs SpecProof for `Registration#eligible?`, `specifications/registration.rb`, and `sig/project.rbs`. The test passed: `1 runs, 8 assertions, 0 failures, 0 errors, 0 skips`.

The fresh report is `reports/final.json`, run ID `947eeff1-0683-4892-9d1c-361191111844`. It reports the same contract digest and all nine baseline obligation IDs, `9/9` exercised, zero missing and unknown, `completion: completed`, `integrity: true`, and `tests_passed: true`. The run ID is distinct from the supplied baseline. Scope lists the intended target and canonical DSL/RBS sources, with no arguments or filters.

## Scope and limitations

This verifies the isolated `run.rb` Minitest entrypoint and the selected `Registration#eligible?` target. The report establishes observed input calls, not assertion semantics or general implementation correctness; the age-18 assertion's expected result comes from `requirements.md`. It does not claim whole-repository or production integration coverage.
