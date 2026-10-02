# Result

Closed the justified age-18 boundary gap for `Registration#eligible?`.

## Evidence and changes

- Read the supplied behavior rule, target method, Minitest suite, DSL declaration, RBS signature, fresh baseline report, and the exported `specproof-test-gaps` skill plus its coverage-report reference.
- Fresh `specproof check` reported no findings or errors. Fresh `plan` had contract digest `03501b28c964e6614a246f1520ecdb367e9d94f021ec3e7ea7b1dfc2f52dad3e`; the uncovered adult lower-endpoint obligation was `f34bb1fa38998396c7ddf02a20ba326da6c30131d696dabee7e7f6acff06daa8` for age `18`.
- Added an assertion for age 18 with true consent. Its failure message records that obligation ID and the independent oracle, `requirements.md`: eligibility starts at age 18 when consent is true. The pre-fix run is preserved in `logs/red-run.json` and `reports/red.json`: one failure at the new assertion, with coverage run ID `a4bd94cf-319a-4ea0-b4d0-8b8f50fa080a` and `tests_passed: false`.
- Changed the boundary comparison from `age > 18` to `age >= 18` in `lib/registration.rb`, the smallest fix supported by the supplied rule.
- The fresh post-fix run is preserved in `logs/final-run.json` and `reports/final.json`. It passed 1 test / 8 assertions, with run ID `34da9e91-2eef-4283-b86b-6266dbcd61cb`. Its contract digest matches the fresh plan and baseline; all 9 expected obligation IDs are present and exercised, with `missing_count: 0`, `unknown_count: 0`, `completion: "completed"`, `integrity: true`, and `tests_passed: true`.
- The final report scope targets `Registration#eligible?`, lists the configured DSL and RBS sources and explicit target, and has empty run arguments with null filters. The captured command is Ruby 4.0.1 `ruby run.rb`; that entrypoint installs the adapter with those declarations and requires `test/registration_test.rb`. No signature, specification, or skill files were changed.

## Limits

SpecProof confirms input-obligation hits; it does not inspect assertion meaning or prove general correctness. The age-18 expected result is supported by the independent supplied requirement and the passing regression. This evidence covers the supplied single-target Minitest run only.
