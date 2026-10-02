# Fresh evaluation result

## Actions and loaded assets

- Read `TASK.md`, `requirements.md`, and `supplied-context.json` in this workspace.
- Explicitly loaded `.agents/skills/specproof-test-gaps/SKILL.md` and its `references/usage.md` report guide.
- Inspected `run.rb`, `specifications/registration.rb`, `sig/project.rbs`, `lib/registration.rb`, `test/registration_test.rb`, and `reports/baseline.json`.
- Ran the required captured offline `check` and analogous `plan`, both with the specified DSL, RBS, and `Registration#eligible?` target.
- Ran the required captured fresh process with `REPORT_NAME=fresh.json` and `ruby run.rb`.

## Current status

The prior baseline report does not prove current coverage. Its source hash is the baseline hash, while the current implementation hash is `49169a649356269f4fd8bd0eb373002b136de78eac1d58e06c4e926b51973ccb`. That current hash matches `supplied-context.json`, which records the edit from `>=18` to `>18` after the baseline.

Fresh `check` completed with no errors or findings. Fresh `plan` returned the same contract digest as the baseline (`03501b28c964e6614a246f1520ecdb367e9d94f021ec3e7ea7b1dfc2f52dad3e`) and the same nine obligation IDs. The plan's age 18 obligation is `f34bb1fa38998396c7ddf02a20ba326da6c30131d696dabee7e7f6acff06daa8`.

The captured fresh suite command was `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby run.rb`, with no test-name filter or exclusion. `run.rb` loads `test/registration_test.rb` after installing the adapter for the selected DSL/RBS target. The test process exited 1: 1 test, 4 assertions, 1 failure at the assertion for age 18. This matches the independent supplied rule, which requires eligibility at age 18 when consent is true, and exposes the current `age > 18` behavior defect.

Fresh report `reports/fresh.json` has run ID `1b68410a-942f-4368-a2b9-f020b16b6035`, the current plan digest, the expected target and canonical DSL/RBS declaration sources, empty arguments, `filter: null`, and `exclude: null`. It reports `completion: completed`, `integrity: true`, `tests_passed: false`, 5/9 obligations exercised, 4 missing, and no collection errors or incomplete reasons. The unobserved obligations are ages 119 and 120, consent nil, and consent false; execution stopped at the failing age 18 assertion before those calls.

## Limits

This is fresh evidence for the selected test command and target only. The report proves observed inputs, not assertion meanings or application correctness. The independent behavior rule supplies the expected outcome at age 18; RBS supplies input types only. No implementation, test, declaration, rule, or skill files were changed. Captured command records and generated reports are retained under `logs/` and `reports/`.
