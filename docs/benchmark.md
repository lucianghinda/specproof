# Small-suite collection timing

This benchmark compares equivalent Minitest subprocesses that call `AgePolicy#adult?` three or six times. The test methods and assertions are generated once for each suite size and run unchanged in baseline and instrumented modes. The instrumented mode installs the optional adapter and verifies that report hit totals match the direct call counter.

Run it from `gems/specproof` with a Minitest 5.27.x installation whose activated gem version and `Minitest::VERSION` both identify the supported release:

```sh
ruby script/benchmark_age_policy.rb
```

The script runs five repetitions per mode by default. Pass a positive iteration count as the first argument for a shorter smoke run.

This recorded run used Ruby 4.0.1 on arm64 macOS, Minitest gem `5.27.0`, runtime `Minitest::VERSION` `5.27.0`, and SpecProof `0.1.0`. The available RubyGems 5.27.0 artifact on this machine had an embedded runtime version of `5.26.2`, so the measurement used an unmodified local rebuild of the `v5.27.0` source tag to meet the adapter's package/runtime version check. No Minitest code was patched for the run.

Each timing includes Ruby process startup, Bundler setup, Minitest startup, the test suite, and report writing. All five repetitions made exactly the number of calls shown; instrumented hit totals matched those counts.

| Suite size | Mode | Calls per run | Wall time, repetitions 1–5 (seconds) |
| --- | --- | ---: | --- |
| 3 tests | Baseline | 3 | 0.229863, 0.231492, 0.218486, 0.235095, 0.229194 |
| 3 tests | Instrumented | 3 | 0.262548, 0.254388, 0.261317, 0.280937, 0.239743 |
| 6 tests | Baseline | 6 | 0.236327, 0.230261, 0.241569, 0.230310, 0.220956 |
| 6 tests | Instrumented | 6 | 0.241652, 0.250458, 0.237547, 0.246748, 0.239821 |

These measurements describe only this tiny fixture and subprocess setup. Process startup dominates much of the elapsed time, so the results do not estimate overhead for a larger application suite.
