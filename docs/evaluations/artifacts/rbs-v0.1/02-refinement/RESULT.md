# Evaluation result

## Actions and assets

- Loaded the supplied `specproof-specify` skill and its `references/usage.md` from `.agents/skills` before authoring the contract.
- Added `specifications/registration.rb` with only the missing behavioral refinement for `age`. The explicitly selected RBS signature already supplies finite candidates for `consent: bool?`, so no DSL declaration duplicates it.
- Kept `sig/project.rbs`, the supplied requirement, and installed skill files unchanged.

## Evidence

- The declaration at `specifications/registration.rb:6` bounds age to `0..120` and marks it exhaustive and disjoint, as stated in the requirements. Lines 7–8 declare `minor: 0...18` and `adult: 18..120`.
- The selected RBS target is `Registration#eligible?`; its signature is at `sig/project.rbs:2`.
- Captured `check` output in `logs/check.json` and `reports/check.json`: SpecProof `0.1.0`, schema 1, no errors or findings. Contract digest: `03501b28c964e6614a246f1520ecdb367e9d94f021ec3e7ea7b1dfc2f52dad3e`.
- Captured `plan` output in `logs/plan.json` and `reports/plan.json`: criterion `input-basics-v1`, with the same contract digest. Age boundary candidates are `0`, `1`, `17`, `18`, `119`, and `120`. Consent candidates are `nil`, `false`, and `true`, imported from RBS line 2.
- Age candidate provenance points to the RBS signature at line 2 and the DSL declarations at lines 6–8, as applicable. The plan gives stable obligation IDs and reasons in `reports/plan.json`.

## Limitations

- The supplied evaluation workspace contains the requirements and RBS signature but no Ruby implementation or existing tests, so this input-only evaluation does not compare runtime behavior against the independent rule.
- The plan proposes boundary candidates for review; it is not a complete or proven test suite and does not establish expected method results.
