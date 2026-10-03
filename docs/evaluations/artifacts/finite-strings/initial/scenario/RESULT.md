# SpecProof finite-string skill exercise

This is a guided fixture exercise in `/private/tmp/specproof-finite-strings-skill/scenario`; it is not adoption in the SpecProof repository or evidence about a real product. The fixture's requirements are fictional and were supplied by the task brief. They are recorded in `requirements.md`: `file_id: nil` returns `"automatic"`, integer `1` returns `"1.pstore"`, and string `"user_123"` returns `"user_123.pstore"`. `payload` is outside this label scenario and is explicitly excluded with a reason. Production fixture code remains unchanged.

The installed CLI reports SpecProof `0.1.0`. Fresh `check` returned no errors or findings, and fresh `plan` returned the `input-basics-v1` criterion and all three correctly typed values. Both report digest `4dcd5d38da2aee680ec507149d1f691928cbeb3cd261d41ea7c54e68063b11e9`. The candidate IDs are:

- `nil`: `341a8e69165da96b2a889f30283eb723c94795743ca9c35a686b1168436be9cc`
- integer `1`: `faf4c2f9131ae71bc68454871cd2949ad43f9c4b22fe39752a0abc4888294bf9`
- string `"user_123"`: `d9b206e067cebe24284b290d9baa12b6a486865c841f5ef1dd61b9cdcd1a2b7f`

All candidates come from `specproof_spec.rb:4`. Scope is `FileLabel#label`, analyzing `file_id`; `payload` is excluded at `specproof_spec.rb:9` because the independent requirements put payload behavior outside this scenario.

The original test bytes are preserved in `test_file_label.original.rb`. The strict baseline at run ID `d7762bb7-e380-4f84-ab5e-ed4433475485` completed with `integrity: true`, `tests_passed: true`, zero unknowns, and one missing obligation: the string candidate. Minitest itself passed 2 tests and 2 assertions. The process exited 1 because `fail_on_missing: true` found that planned string unobserved. This intact report is the pre-string-assertion baseline.

After adding the independently required string assertion, the final test bytes are preserved in `test_file_label.final.rb`. Fresh run ID `2e4f4443-b24c-47a7-9110-e56c24521a7c` completed with `integrity: true`, `tests_passed: true`, zero missing and unknown obligations, no outside-domain observations, errors, or incomplete reasons. Minitest passed 3 tests and 3 assertions; the strict process exited 0. All three planned obligations were exercised once. The contract digest and input scope match the check, plan, and baseline.

The teammate suggestion to use `:user_123` is rejected because a symbol is a different typed value and cannot exercise or satisfy the required string obligation. Dropping the string would also remove an independent requirement from the contract. The finite example demonstrates exact string candidate support for this installed build only; it does not establish coverage of the full `String` domain, arbitrary RBS string imports, or general `FileLabel` correctness.

`version-command.json`, `check-command.json`, `plan-command.json`, `baseline-command.json`, and `final-command.json` retain each invocation's argv, clean configured environment, status, stdout, and stderr. `baseline-coverage.json` and `final-coverage.json` retain the corresponding adapter reports. `test_file_label.rb` is the final test source.
