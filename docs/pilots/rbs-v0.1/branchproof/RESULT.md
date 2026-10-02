# BranchProof RBS adoption pilot

## Finding

The existing RBS signature for `Branchproof::ComparisonReport#exit_code` is sufficient for SpecProof's finite-input analysis. `fail_on_regression` is an optional keyword with type `bool`; the RBS-only plan yields `false` and `true` without a DSL specification or inferred behavioral refinement. Both values were observed in the unchanged focused Minitest run.

This evidence covers only `project/test/test_comparison_report.rb` (2 tests, 8 assertions), not the complete BranchProof suite. No test was added, no gap was manufactured, and the result does not support a general agent-reliability claim.

## Final package and skill provenance

- Final SpecProof package SHA-256: `dd34a15eeda389e3453c8cfa6544b22bbaf2d1578aded2000f7f74e2aab2694d`. Runtime loaded version 0.1.0 from the live worktree at `/Users/luciang/Dropbox/workprojects/opensource/specproof/gems/specproof/tmp/worktrees/rbs-scalar-integration`. All 17 package `lib/` files match the final installed package and current live worktree; `lib/specproof.rb` SHA-256 is `d64778b00af5c03ffbfc70b76184ba73477ddec3bd7a1bbe1c544dd9b292550c` in both.
- The two final exported skills and both references match byte-for-byte across the installed package, final export, and pilot copy. Hashes and paths are in `skill-and-package-manifest.json`.
- Check, plan, and runtime evidence were refreshed after the public-name-guard source update. Previous evidence remains in `pre-final/`.

## Verification

- Source: BranchProof commit `85611af97461d1714bffffff42a4719952b9cbc4`. All 59 manifest hashes match the unchanged pilot copy and original project checkout; the original checkout is clean.
- Signature: `project/sig/branchproof.rbs:355` — `def exit_code: (?fail_on_regression: bool) -> Integer`. Return type is not analyzed.
- Final-package check and plan exited 0 with empty errors/findings and matching digest `d0f6f2f3dda709bfeba00b3b10e458e62995ee24a0e1f716b14024e3f110fc10`. Plan values and IDs:
  - `2c391c03cf1537c94e21d7936bde6066e1d637524e0fc2c915e743210eb94258` — `fail_on_regression: false`
  - `1a4851e3489c5ee8800a578a0ab1d4697ac4e692d5215c5ebc667f9040fa446b` — `fail_on_regression: true`
- Existing assertions remain at `project/test/test_comparison_report.rb:27-28`: true produces exit code 1; the default false value produces 0. Line 32 asserts exit code 2 for an incomplete comparison.
- Fresh runtime report `56cbf645-432f-441d-b1b1-a6a6f5ac5270` completed with intact integrity and `tests_passed: true`; it records 2/2 exercised obligations, zero missing/unknown/outside-domain values, and no errors or incomplete reasons. Runtime IDs match plan IDs; hits are false=2 and true=1.
- Runtime scope names only `Branchproof::ComparisonReport#exit_code`. `declaration_sources` contains `specifications: []`, one canonical RBS path, and that target. Runtime arguments are empty; filter and exclude are null. The runner script manually loads only the focused test file; report scope alone does not prove test-file loading.
- Baseline and refreshed runtime each passed 2 tests and 8 assertions. Raw command/output logs are `logs/baseline-comparison-report.log` and `logs/rbs-runtime-run.log`; this was not a full-suite run.

## Reproduction

From the pilot root, use Ruby 4.0.1 and the pilot's normal Bundler environment with `SPECPROOF_ROOT` set to the live worktree:

```sh
ruby -S bundle exec ruby -Iproject/test logs/run_branchproof_rbs_coverage.rb
```

The runner explicitly requires `branchproof/comparison_report` before adapter installation, uses `specifications: []`, supplies the original RBS file and target, and loads only the focused test file. Full environment and output are retained in `logs/rbs-runtime-run.log`.

Offline logs and parsed reports are `logs/rbs-check.log`, `logs/rbs-plan.log`, `reports/rbs-check.json`, and `reports/rbs-plan.json`. Refreshed runtime report and package evidence are `reports/rbs-runtime-coverage.json` and `reports/rbs-runtime-environment.json`.

## Limits

Coverage records effective bound values; `argument_presence` is `not_observed`, so a false hit does not distinguish an omitted keyword from explicit `false`. RBS supplies no expected-output rule. Expected return codes here come from existing assertions only. This pilot reports input exercise, not method correctness or complete project coverage.
