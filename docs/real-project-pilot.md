# Real-project pilot: configuration lookup and adoption limits

The first pilot demonstrated a useful test gap on an existing method, and exposed two concrete adoption limits. It did **not** produce three successful coverage integrations: one target was supported, and two representative targets were rejected. Luna agents performed discovery, used the exported skills, and independently reviewed the evidence. Original repositories were left unchanged.

## Installation

The development bundle now selects the correctly labeled published Minitest 5.26.2 release. The adapter supports `>= 5.26.2` and `< 5.28.0`, while continuing to reject package/runtime minor-version mismatches. See [package checksums and compatibility evidence](minitest-compatibility.md).

The pilot used standard Bundler `vendor/bundle` installation, with the verified official package in `vendor/cache`. Sandbox restrictions prevented writing a global executable wrapper, and Bundler could not reach its index host; a normal `bundle install --local` from that package cache succeeded. No dependency source, runtime version constant, or global gem installation was changed. Core development checks use the existing published 5.26.2 installation; Ruby 3.3/3.4 verification used local bundles with ambient Ruby 4 gem paths cleared.

Bundler loaded SpecProof from its cached path dependency. Every cached library file matches the current gem library by SHA-256; those hashes are in the pilot manifest. The retained archive excludes that generated cache and recreates it from `SPECPROOF_ROOT` during installation.

## Three candidate methods

| Existing method | Result | Consequence |
| --- | --- | --- |
| `QualityGate::Config#fetch(key)` | Supported. Eight shipped symbol keys form an explicitly scoped finite input domain. | Measure and close a gap in its existing configuration tests. |
| `PStoreLogger#save(data, file_id: nil)` | Collector rejects the optional keyword with `unsupported_parameters`. | No coverage claim. The scalar signature-probe declaration is only a candidate subset of the broader PStore data domain. |
| `Agent::SessionContext::SemanticCategories.lookup(identifier)` | Declaration rejects class-method syntax with `invalid_target`. | No coverage claim. Do not invent an instance-method wrapper to make the pilot pass. |

The [rejected-candidate archive](pilots/2026-10-02/rejected/workspace.tar.gz) retains exact source files, source commits/hashes, original test references, the binding probe, command logs, and errors. The PStore probe used Ruby 3.4.7's standard library because `pstore` is no longer a default gem under Ruby 4; no new dependency was installed. The supported pilot used Ruby 4.0.1 throughout.

Discovery also examined SimpleResult, the Minitest reporter, BranchProof, Agent Sessions, Agent Session Context, Agent ACL, and Guardrails for Rails. Many methods require optional parameters, class-method targets, strings, or structured objects outside the first release's supported subset. This was a bounded local survey, not proof that no suitable three-method project exists elsewhere.

## QualityGate result

Source revision: `8af0893de378cfd8076392d39b874f44987d818c`. All **143 copied project files** retain their original hashes. The pilot runs the unchanged `test/quality_gate/config_test.rb` file, not the whole QualityGate suite or its Rails/external-tool gates. The minimal pilot bundle loads this focused library/test slice without installing QualityGate's broader development dependencies.

The domain includes all eight shipped `Config.defaults` keys. It excludes arbitrary hash keys and invalid configuration keys; 100% here means exercise of those eight scoped inputs only.

| Run | Tests / assertions | Input obligations exercised |
| --- | --- | --- |
| Existing configuration tests | 45 / 342 | 7 / 8; `:files` unobserved |
| Existing tests plus one added test | 46 / 350 | 8 / 8 |

The added test compares `fetch` results with the exact shipped defaults. Its oracle is grounded in the existing test that asserts a default-loaded configuration's `to_h` equals `Config.defaults`. It makes eight assertions and includes obligation IDs and the original assertion location in failure messages. No production behavior was changed or defect invented; these assertions pass against the existing implementation.

The fresh final report has a distinct run UUID, unchanged domain/digest and obligation IDs, positive hits for all eight values, and no unknown evidence or integrity errors. Read the [agent's detailed result](pilots/2026-10-02/quality_gate/RESULT.md), [specification](pilots/2026-10-02/quality_gate/config_fetch_spec.rb.txt), [added test](pilots/2026-10-02/quality_gate/config_fetch_added_test.rb.txt), [baseline report](pilots/2026-10-02/quality_gate/baseline-coverage.json), and [final report](pilots/2026-10-02/quality_gate/final-coverage.json).

## Timing

Five paired subprocess runs executed the **same original 45 tests and 342 assertions**, with no added tests, fixed seed 12345, and the adapter enabled only in the instrumented mode. Every instrumented report retained the same plan, exactly the original `:files` gap, completed integrity, and 27 observed selected-method calls. [Raw timings](pilots/2026-10-02/quality_gate/timings.json) and per-run logs/reports are retained.

| Mode | Wall times, seconds | Median |
| --- | --- | --- |
| Baseline | 0.307118, 0.300959, 0.298459, 0.300013, 0.318318 | 0.300959 |
| Instrumented | 0.326725, 0.338711, 0.328865, 0.353294, 0.341357 | 0.338711 |

The median difference was about **38 ms (12.5%)** for this focused subprocess workload. Timings include Ruby/Bundler startup, requiring the adapter, collection, and report I/O. Baseline always ran first; five pairs do not establish a general overhead rate or isolate collector cost. They provide a reproducible comparison for this particular suite.

## Reproduce

The [supported workspace archive](pilots/2026-10-02/quality_gate/workspace.tar.gz) includes unchanged library/tests, license, Gemfile/lock, verified package cache, exported skills, added test, specification, runner, reports, and source hashes. It excludes the installed dependency directory. Unpack it into an empty directory, then use Ruby 3.3 or newer:

```sh
export SPECPROOF_ROOT=/absolute/path/to/gems/specproof
bundle config set --local path vendor/bundle
bundle install --local
export MT_NO_PLUGINS=1
export PILOT_PROJECT_ROOT="$PWD/project"
export PILOT_SPECIFICATION="$PWD/config_fetch_spec.rb"
export PILOT_REPORT="$PWD/fresh-coverage.json"
PILOT_ADAPTER=1 PILOT_ADDED=1 bundle exec ruby pilot_runner.rb
```

From the SpecProof gem checkout, compare unchanged original tests with:

```sh
ruby script/benchmark_project_pilot.rb /absolute/path/to/unpacked/pilot 5
```

[The manifest](pilots/2026-10-02/manifest.json) records archive/file hashes and the exact updated skill bytes. The earlier twelve-scenario evaluations remain historical evidence for their original assets; this pilot is a separate fresh application of the updated instructions.

The retained archive was also unpacked into a second empty directory and installed using `bundle install --local`. A fresh run there passed 46 tests and 350 assertions with 8/8 obligations exercised, confirming that reproduction works independently of the original pilot's installed dependency directory.

## Next implementation slice

Support **optional scalar positional and keyword parameters** next, while preserving the current directly owned instance-method scope. Define observations as effective bound argument values after Ruby applies defaults. Do not evaluate defaults statically, replay calls, or infer that an observed default value proves the argument was omitted.

Before implementing, add TracePoint fixtures proving default evaluation timing, omitted versus explicit equal values, exceptions in default expressions, and unsupported non-primitive effective values. Preserve whole-tuple validation, shared IDs, and unknown evidence. Then rerun the PStoreLogger pilot on an explicitly declared primitive-data scenario subset with independent persistence assertions.

Class-method targets, finite string domains, and richer object domains remain separate later decisions. This slice addresses an observed adoption barrier without taking on all of them at once.
