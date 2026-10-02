# QualityGate Config#fetch pilot

## Scope and contract

Target: `QualityGate::Config#fetch(key)`, defined at `project/lib/quality_gate/config.rb:272`. The key input is the finite set of all eight symbol keys in `Config::DEFAULTS` at `project/lib/quality_gate/config.rb:19-36`: `:format`, `:files`, `:adapters`, `:commands`, `:timeouts`, `:coverage`, `:compare_point`, and `:rubocop_config`. The specification declares the full finite domain with eight singleton partitions, marked exhaustive and disjoint. This scope does not cover arbitrary Ruby hash keys or invalid configuration keys.

The actual exported skills and references were read before execution:

- `.agents/skills/specproof-specify/SKILL.md` and `references/usage.md`
- `.agents/skills/specproof-test-gaps/SKILL.md` and `references/usage.md`

The expected values come from `Config.defaults`. The independent existing test `ConfigTest#test_absent_file_uses_defaults` asserts that `Config.load` for an absent file returns exactly `Config.defaults` (`project/test/quality_gate/config_test.rb:8-14`, assertion at line 12). The new assertions compare each `fetch` result on such a loaded config with the corresponding shipped default. No return policy beyond that existing assertion was inferred.

## Check and plan

Environment: Ruby 4.0.1, Bundler, published Minitest 5.26.2, SpecProof 0.1.0, and `MT_NO_PLUGINS=1`. Commands ran from this pilot directory with:

```text
PATH=/Users/luciang/.rubies/ruby-4.0.1/bin:/usr/bin:/bin
SPECPROOF_ROOT=/Users/luciang/Dropbox/workprojects/opensource/specproof/gems/specproof
MT_NO_PLUGINS=1
bundle exec specproof check config_fetch_spec.rb --format json
bundle exec specproof plan config_fetch_spec.rb --format json
```

The check report at `check.json` has `errors: []` and `findings: []`. The plan at `plan.json` uses `input-basics-v1` and has contract digest `245fef525bdc891fbb21e9329ba337c86b5f8e87abaa2d341a6ae6e47eb31ebb`. It contains eight finite-value obligations, all sourced to the input declaration at `config_fetch_spec.rb:6`:

| Key | Obligation ID |
| --- | --- |
| `:adapters` | `6c51acfaf3ca93069569eeac2b312528afa6f9fe4b48030f866077f9e1831c06` |
| `:commands` | `bd8c3a6a72d16acf15e05fb38f1062329ac39288b109ba2a5ac6de53b887e9eb` |
| `:compare_point` | `a144c31c5998d837a2872c927af4ba4094a8c0a50edb3390d61ade92a828c8fe` |
| `:coverage` | `ba01d4cdd7b2e022b04ed4b9efcfd5b122d0effe246f29f7bc03e6b4078b270a` |
| `:files` | `8a6f0c87ec68c1903e6fef24bd5e7ef017dedbc57e64865b83aa0c8bb02c0d83` |
| `:format` | `0c4f97c395bc63e780baa09b986aabd2adcbe41d39caac63bbda907d15098054` |
| `:rubocop_config` | `0636ff11a001c0b50b611149711b4959dcd5a728c490f06b9638412e467ddd16` |
| `:timeouts` | `4886e8f1a023a7286e748c0faf745a2dc8edf95f370c39cd510992c83d7da974` |

## Baseline and fresh focused run

`pilot_runner.rb` requires the unchanged `project/test/test_helper.rb` and original `project/test/quality_gate/config_test.rb`. With the adapter installed once and only the original test file loaded, the baseline run passed **45 tests and 342 assertions**. Its report is `runs/baseline/coverage.json`, with stdout and stderr retained beside it. It had a fresh run ID `f8aaa95e-af41-4ce5-82e8-48b33dd393d9`, the plan digest above, and 7/8 obligations exercised. The only unobserved key was `:files`; this indicates missing call evidence in this focused suite, not a production defect.

`config_fetch_added_test.rb` adds one test with eight assertions. Each failure message includes the plan obligation ID and the existing defaults assertion location. The final run freshly required the same original test file plus the added test, using `PILOT_ADAPTER=1` and `PILOT_ADDED=1`:

```text
PATH=/Users/luciang/.rubies/ruby-4.0.1/bin:/usr/bin:/bin
SPECPROOF_ROOT=/Users/luciang/Dropbox/workprojects/opensource/specproof/gems/specproof
MT_NO_PLUGINS=1
PILOT_PROJECT_ROOT=<pilot>/project
PILOT_SPECIFICATION=<pilot>/config_fetch_spec.rb
PILOT_REPORT=<pilot>/runs/final/coverage.json
PILOT_ADAPTER=1 PILOT_ADDED=1
bundle exec ruby pilot_runner.rb
```

The retained final outputs are `runs/final/stdout.txt`, `runs/final/stderr.txt`, and `runs/final/coverage.json`. The fresh run passed **46 tests and 350 assertions** with no failures, errors, skips, or stderr output. Its new run ID is `5589df7d-206d-4c47-92f9-9505555662de`, distinct from baseline. The report is completed, integrity and tests-passed are true, all eight original plan IDs remain present and are `exercised` with positive hit counts, and `missing_count`, `unknown_count`, `errors`, `incomplete_reasons`, and `outside_domain` are empty. The digest matches both baseline and the current plan.

## Source preservation and limits

No project source, original test, dependency file, vendor directory, or bundle configuration was edited. `verify_source_manifest.rb` checked all 143 copied source files against `source-manifest.json` and commit `8af0893de378cfd8076392d39b874f44987d818c`; all hashes matched. The original config test SHA-256 remains `d5ceb4b65f9e0945ed96fa6c5d023857deade8e679b9ae9b83f79eba4b57277f`.

The new assertions establish calls and preserve the exact shipped-default behavior already asserted by the project test. SpecProof observes calls; this pilot does not claim general correctness of `fetch`, coverage for other methods, or coverage of the full QualityGate suite.
