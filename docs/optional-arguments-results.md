# Optional scalar arguments

This implements the [approved continuation](optional-arguments-plan.md) after the first real-project pilot rejected `PStoreLogger#save(data, file_id: nil)`. Named optional positional and keyword parameters now work alongside required parameters. Every parameter must still be declared, and observed values must remain within the supported scalar representation.

The production change widens the collector's parameter-kind allowlist; Ruby still evaluates and binds arguments. The adapter adds two scope fields under report schema 1: `input_semantics: "effective_bound_values"` and `argument_presence: "not_observed"`. The planner, criterion, contract digest semantics, and obligation IDs are unchanged.

## Meaning of the evidence

Omitting an argument whose default is `nil` and explicitly passing `nil` exercise the same value obligation. This does not establish omission coverage. Defaults execute once through normal Ruby execution, including side effects and dependent defaults. A default that raises before method entry yields no entry observation for that target and preserves the original exception. Another selected method called during default evaluation can still contribute its own entry observation.

A primitive value outside a declared domain invalidates the whole tuple. A non-primitive effective value, including a default, makes selected-target collection incomplete. Existing positive hits remain evidence, while unhit obligations become unknown. Rest parameters, keyword-rest, forwarding, explicit blocks, class-method targets, and structured objects remain outside this release.

## Adoption boundary

The PStoreLogger continuation declares an explicit primitive scenario subset: `data` in `[nil, false, true, 0, :event]` and `file_id` in `[nil, 1]`. Those yield seven marginal value obligations, not Cartesian combinations or the complete domain of marshalable objects.

The original project tests save Hash payloads. Their ordinary execution must keep passing; instrumenting the full suite must honestly report incomplete collection on those object-valued inputs. A fresh filtered run of separate scalar persistence tests can establish exercise of the declared subset only.

Assertions are grounded in the project's documented storage layout and filename behavior, and in Ruby's [PStore contract](https://ruby-doc.org/3.4.1/stdlibs/pstore/PStore.html). PStore stores marshalable Ruby values through transactions. Added tests read the persisted payload, distinguish stored `nil` from a missing key, preserve `false`, check timestamps, and check explicit-ID collision behavior. No production behavior change is needed for that scenario.

| Run | Minitest outcome | Collection outcome |
| --- | --- | --- |
| Original suite | 7 tests, 23 assertions pass | Uninstrumented baseline |
| Original suite with adapter | 7 tests, 23 assertions pass | Incomplete, seven unknown obligations, `non_primitive_argument`; invocation fails |
| Expanded suite | 13 tests, 63 assertions pass | Uninstrumented regression check |
| Expanded suite with adapter | 13 tests, 63 assertions pass | Incomplete on Hash payloads; invocation fails regardless of positive hits |
| Explicit scalar filter | 6 tests, 40 assertions pass | Complete, seven of seven marginal obligations exercised; invocation succeeds |

Luna used the newly exported skills in an isolated copy of PStoreLogger at source commit `959e37410bac42ba47e43ee8da006ce9550d9f50`. Source hashes, exact skills, assertions, commands, reports, and a relocatable workspace are retained in the [pilot artifacts](pilots/2026-10-02-optional/pstore_logger/results.md) and [archive](pilots/2026-10-02-optional/pstore_logger/workspace.tar.gz). The expanded instrumented run's positive hit count can depend on test order before a Hash disables the target; completeness remains false in every case. All report IDs are fresh and their seven obligation IDs and contract digest agree with the offline plan.

The archive was extracted into a fresh temporary directory, installed through ordinary `bundle install --local` with the checksum-verified Minitest package, and rerun successfully. [Reproduction evidence](pilots/2026-10-02-optional/pstore_logger/reproduction.json) retains the new report IDs, command exits, and filtered results. Loaded library paths and hashes are separately captured in the runtime probe. The archive excludes installed dependencies; its cached official Minitest package is retained for offline installation. The local reproduction uses CRuby 3.4.7 so PStore comes from its standard library, with unrelated ambient gem and Bundler variables cleared.

To repeat locally, extract the archive into an empty directory, set `SPECPROOF_ROOT` to this gem checkout, install with Ruby 3.4's `bundle install --local`, and invoke `ruby run_pilot.rb`. The retained runner records this machine's Ruby path; adjust `RUBY_BIN` and its environment `PATH` for another machine. The driver exits successfully only when expected child outcomes match: full instrumented children fail on integrity, while the filtered scalar child succeeds. Its success does not relabel the incomplete child reports.

The earlier [pilot](real-project-pilot.md) and agent evaluation archives retain their original skill bytes and implementation context. This continuation records newly exported skills separately; it does not reinterpret earlier rejected probes as successful runs.

## Verification

- Full suites pass separately on CRuby 3.3.6, 3.4.7, and 4.0.1 with published Minitest 5.26.2: **131 runs, 663 assertions**, no failures, errors, or skips.
- The Ruby 4.0.1 default Rake task passes tests and RuboCop: **83 files**, no offenses. Its deliberate method-redefinition fixtures emit expected Ruby warnings.
- `bin/check` passes syntax checks, packaging and skill checks (**2 runs, 66 assertions**), and gem build. Existing RBS declarations validate; that does not type-check the implementation or import RBS specifications.
- Collector tests cover optional positional and keyword bindings, mixed signatures, dependent defaults, side effects, raising defaults, nested selected calls, and preserved unsupported forms. Subprocess tests verify omitted/explicit `nil` hits, offline-plan IDs and digest equality, whole-tuple domain validation, and incomplete evidence on non-primitive defaults.
- Luna specification and quality reviews passed after adding the two missing acceptance cases. Independent pilot review and source/hash/report checks passed, including actual loaded runtime paths and reproduced child exit statuses.

No runtime dependency was added, no external project's source was modified, and no gem or branch was published. Remote CI execution and arbitrary-object collection remain unverified or deferred.
