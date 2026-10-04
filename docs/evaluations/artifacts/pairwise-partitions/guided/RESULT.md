# Guided partition-pair exercise

The installed SpecProof CLI reported version `0.1.0`. The specification passed
`check` with no errors or findings. Its fresh plan used
`pairwise-partitions-v1`, digest
`ce20c25f686bcb8e62d8979816858f2937dc6cee570898107ef416093687a79c`, and
four age-category/country pair obligations:

| Age category | Country | Plan obligation ID | Baseline |
| --- | --- | --- | --- |
| minor `[0..17]` | `de` | `e47c6c3a0035ee9e317ea90df1dde67dc0d834624b89f6f3936a19f355c29b37` | Missing |
| minor `[0..17]` | `ro` | `55b00794549580aae00deb68e4e3a4751fab451138b7f0c8a08adc63eb076afc` | Exercised, 1 hit |
| adult `[18..120]` | `de` | `b581f2190a5d1d8b565bdd53e5c87005dcb14ba471c4e5b7215c765b86b3eddb` | Exercised, 1 hit |
| adult `[18..120]` | `ro` | `ee3acdbc5d1692d098e61bb3df23a9347ea3678ca466365cd8bb29ba25aec06f` | Exercised, 1 hit |

The refreshed baseline was a completed, intact, unfiltered run: run ID
`ca09e606-c617-4fa7-8515-2974cea71977`, `tests_passed: true`, 3/4 pairs
exercised, and no excluded pairs. Its `input_scope` analyzed both `age` and
`country`, with no excluded inputs. SpecProof suggested `age: 0, country:
"de"` for the missing minor/de pair. The suggestion had no expected result.

The added assertion in `test_missing_category.rb` uses that suggested full
assignment and the independent `requirements.md` rule that every age below 18
is ineligible. The existing specification, production method, and assertions
in `test_age_policy.rb` were left unchanged.

The fixture already contains a dormant copy of the missing-case test, gated by
`ADD_MISSING_CATEGORY=1`. The first final-run attempt accidentally enabled that
fixture test along with the added test; it is preserved as
`raw-shared-flag-run.log` and `raw-shared-flag-report.json`, but is not used as
final evidence. The runner now loads only the added test under its separate
`SPECPROOF_ADDED_TEST=1` flag, with `ADD_MISSING_CATEGORY` unset.

The corrected fresh final run was completed and intact, with the same digest
and criterion, run ID `a8ad2e14-4a2d-4f39-b716-09c18d5cd59e`, all four planned
pairs exercised, zero missing pairs, and `tests_passed: true` (2 tests, 4
assertions, no failures or errors). The run had no filters or exclusions and
analyzed `age` and `country`. `suggest` accepted this report and returned zero
missing obligations and zero suggestions.

To test report validation, a temporary Ruby script changed the minor category's
upper bound from `17` to `16` in a copy of the refreshed baseline report. `suggest`
rejected that copy with `coverage_contract_mismatch` and message
`coverage obligation contents do not match plan`. The original baseline report
was preserved unchanged.

This final verification used the rebuilt installed gem. The fixture hashes
before and after the refresh matched: `specification.rb`
`2ce736a9c7faba531e0a05cbf1c6565685063949098362e0ba77c43c99068e64`,
`test_age_policy.rb`
`85666533d3346995863fb1d1c7d832bd17cac545a9f4a632014e9aedb86641f5`, and
`lib/age_policy.rb`
`932535f894d739f3ffbd72ca3dc7ea9b9437b8773c1988d4811003bcca436163`.

Pairwise partition coverage measures category pairs, not boundaries or behavior
equivalence within each category. The lower endpoint `0` is the suggestion's
call value; the expected result comes from `requirements.md`. Full pair coverage
does not prove complete method correctness.

## Preserved evidence

- `raw-version.txt`
- `raw-check.json`, `raw-check.err`
- `raw-plan.json`, `raw-plan.err`
- `raw-baseline.log`, `raw-baseline-report.json`
- `raw-suggest.json`, `raw-suggest.err`
- `raw-shared-flag-run.log`, `raw-shared-flag-report.json` (superseded attempt)
- `raw-final.log`, `raw-final-report.json`
- `raw-final-suggest.json`, `raw-final-suggest.err`
- `raw-baseline-report-bounds-changed.json`
- `raw-mutated-suggest.json`, `raw-mutated-suggest.err`

The offline commands used the installed executable with the supplied isolated
Ruby environment:

```sh
specproof check specification.rb --format json
specproof plan specification.rb --criterion pairwise-partitions-v1 --format json
specproof suggest specification.rb --report raw-baseline-report.json --format json
specproof suggest specification.rb --report raw-baseline-report-bounds-changed.json --format json
```

The baseline runner command was:

```sh
SPEC_PROOF_REPORT=raw-baseline-report.json ruby coverage_runner.rb
```

The corrected final runner command used only the separate added-test flag and
wrote `raw-final-report.json`:

```sh
SPEC_PROOF_REPORT=raw-final-report.json SPECPROOF_ADDED_TEST=1 ruby coverage_runner.rb
```

Each command above ran with the exact environment supplied for the exercise.
