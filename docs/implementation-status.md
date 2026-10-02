# First usable release implementation

The [approved plan](../../../docs/superpowers/plans/2026-10-02-first-usable-release.md) is implemented inside this gem on branch `implement/first-usable-release` and recorded in the implementation commit containing this document. The gem remains unpublished. Verification below records local execution on 2026-10-02; GitHub Actions has been configured but has not been run remotely.

## Scope and coordination

- Core: explicit scalar input declarations, exact partition checks, `input-basics-v1`, deterministic human/JSON reports.
- Runtime: bounded streaming input evidence for selected serial Ruby method calls; optional Minitest 5.27 integration.
- Agent interface: two packaged skills, explicit offline export, isolated behavioral evaluations.
- Existing development RuboCop/Rake tooling is retained; no new runtime dependencies.
- Public namespace: `SpecProof`; preserve scaffold compatibility through `Specproof`.

## Delivered work

- Tasks 1–4: immutable scalar domains, trusted Ruby declaration loading, exact partition checks, shared `input-basics-v1` planning, human and JSON CLI reports.
- Task 5: bounded TracePoint collection for directly owned public instance methods with required positional/keyword inputs. Unsupported or duplicate resolved bindings, redefinition, and changed constant paths cannot produce complete evidence.
- Tasks 6–7: streaming counters, whole-tuple input validation, positive versus unknown evidence, optional serial Minitest adapter with fresh run IDs and atomic reports, optional strict missing-obligation failure.
- Task 8: [executable boundary workflow](../examples/age_policy/README.md), shipping and gap examples, [report contract](report-format.md), packaging, API signatures, compatibility checks, and [timing measurements](benchmark.md).
- Task 9: two packaged skills, conflict-preserving explicit export, and [retained agent evaluations](evaluations/agent-skills-v0.1.md).

Luna subagents implemented independent slices and reviewed specification conformance, runtime correctness, code quality, and evaluation outcomes. The implementation uses one shared obligation model rather than duplicating boundary logic in runtime coverage.

## Acceptance evidence

| Plan criteria | Evidence |
| --- | --- |
| A01–A04 | Loader/checker/planner tests cover unresolved and autoloaded target names, exact gap/overlap witnesses, large domains without enumeration, small-domain reference comparisons, and finite-value identity. |
| A05–A06, A16 | Planner/coverage share obligations and IDs. CLI/report tests cover deterministic schema-versioned JSON, typed values, provenance, errors, and exit codes. |
| A07–A11 | Collector/coverage/subprocess tests cover scope, method identity, invalid tuples, bounded retained evidence, interruption, changed definitions/constants, original failures/exceptions, strict mode, and unknown evidence. |
| A12 | Shipped runner and workflow tests show passing tests with an age-18 gap, a meaningful assertion failing against the boundary bug, and the corrected implementation exercising all six unchanged obligations. |
| A13–A14 | Local suites pass on CRuby 3.3.6, 3.4.7, and 4.0.1. Actual gem installation and CLI export work outside the checkout. Remote matrix execution remains unobserved. |
| A15 | Packaged skill/reference validation, installed-gem export, idempotence, conflict preservation, symlink rejection, and paths containing spaces are tested. |
| A17–A19 | All six scenarios passed two fresh attempts with the final skills (12 accepted outcomes), independently audited. Baselines, discarded attempts, final files, hashes, and real Codex client positive/negative discovery runs are retained. Small fixtures do not establish general agent reliability or a causal improvement rate. |

## Final local verification

- `bin/test`: **111 runs, 562 assertions, zero failures, errors, or skips**, separately on Ruby 3.3.6, 3.4.7, and 4.0.1.
- Default `bundle exec rake` on Ruby 4.0.1: full suite and RuboCop pass; **81 files**, zero offenses.
- `bin/check` from outside the checkout: syntax checks, skill/package tests (**2 runs, 66 assertions**), and gem build with its library present pass.
- RBS 4.2.0 `rbs -I sig validate` passes. This validates declarations, not implementation type checking.
- Five benchmark repetitions per mode preserve unchanged test bodies and exact 3/6 call counts; report hits match. No real-application overhead claim is made.

### Minitest validation environment

The locally available gem labeled Minitest `5.27.0` contained runtime version `5.26.2`. The adapter correctly rejects that mismatch. Validation used unmodified library files from the official `v5.27.0` source tag, packaged into an isolated temporary GEM_HOME. Neither global gems nor the runtime version constant were patched. Source archive SHA-256: `766c98a1d07df624320f69a013bd11994506eec930ce70964f87c7d2ee8a97c7`.

Both activated package and runtime versions must identify Minitest 5.27.x. Installations encountering the mismatched artifact must resolve their Minitest installation before runtime collection works. Offline checking/planning and skill export do not need Minitest.

## Limits and release follow-up

This release checks explicit scalar input specifications and measures exercised input candidates; it does not prove implementation behavior or assertion quality. Declarations are trusted executable Ruby. Collection requires stable constant bindings and selected definitions in a serial same-process/thread window. Transient constant changes restored before final inspection are not detected.

Sorbet/RBS importers, output contracts, inferred partitions, state machines, combinatorial criteria, SMT, parallel collection, and MCP remain deferred. API signatures do not constitute an RBS specification importer.

Model evaluations preceded the final additive constant-binding guards and example-runner convenience changes; deterministic tests and review cover those changes. Skill bytes remained unchanged. Remote CI, a real-application pilot, and publishing remain release follow-up work. No gem was published and no branch was pushed.
