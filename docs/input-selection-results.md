# Explicit input selection results

The [approved implementation plan](superpowers/plans/2026-10-03-input-selection.md)
is implemented on `implement/input-selection`, based on the completed RBS branch.
Core implementation commit: `23d6966`; documentation and skills: `33b8634`. Work is isolated in
`tmp/worktrees/input-selection`; the original checkout and RBS worktree are
unchanged. No publication or merge is included.

## Delivered behavior

```ruby
SpecProof.define "PStoreLogger#save" do
  exclude_input :data, reason: "Payload contents are outside this nil/1 file-ID scenario coverage"
  input :file_id, values: [nil, 1]
end
```

The collector checks that analyzed and explicitly excluded names together
exactly match the selected method's named parameters. It reads only analyzed
bindings. Excluded Hash or object values therefore do not invalidate scalar
collection; unsupported analyzed values still do. A missing declaration, typo,
or newly added parameter cannot silently become an exclusion.

Exclusions require a name, nonblank reason, and declaration source. A target
must retain at least one analyzed input. Default specifications remain strict.
Existing method-shape, redefinition, constant-binding and collection-lifecycle
checks remain in force. Tests still run when collection cannot prepare, and
their actual result is reported separately from collection integrity.

RBS can import remaining finite inputs from an exclusions-only DSL declaration.
The reader validates the complete selected signature before skipping excluded
types. Unsupported analyzed types and union members still fail atomically.
Review found and fixed an edge case where excluding every RBS argument could
otherwise let a nonexistent DSL input reach planning.

Offline check/plan and runtime reports share `scope.completeness_scope` and
`scope.input_scope`, including analyzed names and excluded names/reasons/sources.
Human output discloses exclusions. Sorted excluded names affect the contract
digest; reason text and provenance do not. Legacy no-exclusion digest bytes,
criterion, and per-input obligation IDs remain unchanged. Compare scope and
digest as well as IDs when consuming reports.

## Changes and simplifications

- `lib/specproof/{model,loader,composer,collector,report,minitest,cli}.rb`:
  declaration-owned exclusions, selected binding reads, shared reporting.
- `lib/specproof.rb` and `lib/specproof/sources/{rbs,rbs_projector}.rb`:
  full-signature validation followed by deliberate type projection. Removed
  duplicate name validation from the public loader.
- `sig/specproof.rbs` and focused loader/composer/collector/report/RBS workflow
  tests: API metadata and regression coverage.
- `skills/specproof-{specify,test-gaps}/`, README and report documentation:
  scoped adoption, valid baseline collection, preserved test-only boundaries,
  and honest failure reporting.
- [Runnable example](../examples/input_selection/README.md): ordinary Hash
  payloads, an analyzed boolean, and independently specified assertions.

Selection travels with the existing specification; there are no separate CLI
or Minitest selection options to synchronize. The planner and coverage tuple
validation are reused. No dependency or new domain kind was added; core runtime
dependencies remain zero.

## Verification

| Check | Result |
| --- | --- |
| CRuby 3.3.6 / 3.4.7 / 4.0.1 | Each: 166 core tests, 822 assertions; 46 optional RBS tests, 425 assertions; zero failures, errors or skips |
| Locked default Ruby 4 bundle | `bundle exec rake` passed; RuboCop 1.90 inspected 98 files without offenses |
| Package checks | `bin/check` passed syntax, installed-package and skill checks: 2 tests, 76 assertions; real gem built |
| API signatures | RBS 4.2.0 validation passed on all three Ruby versions |
| Shipped example | 4 tests / 4 assertions pass; both selected boolean obligations exercised |
| Independent reviews | Luna specification and quality reviews approved core and documentation after fixes |

[Raw matrix records](pilots/input-selection/matrix/) retain commands, versions,
outputs, exit statuses and library hashes. These runs recorded the actual
pre-commit working-tree state at `7222d96`; their 17 library hashes match the
committed implementation. Provenance records were not rewritten after commit.

Independent audit records cover the [pilot](pilots/input-selection/audit/pilot.json),
[matrix](pilots/input-selection/audit/matrix.json), and
[agent evaluation artifacts](evaluations/artifacts/input-selection/independent-final-audit.json).

## Existing-project adoption

The [PStoreLogger pilot](pilots/input-selection/README.md) uses its unchanged
source at `959e37410bac42ba47e43ee8da006ce9550d9f50`. The same ordinary Hash-based
suite passes both before and after instrumentation: **7 tests, 23 assertions**.
The selected `file_id` scenario covers `nil` and integer `1`; both obligations
are exercised, with intact collection and matching offline/runtime IDs and
digest. The five copied source/test files retain their original hashes.

This is a finite scenario subset, not the complete accepted file-ID domain.
PStoreLogger also documents string IDs, which this milestone does not model.
No additional test or coverage gap was invented for this adoption result.

## Agent workflow evidence

The [evaluation record](evaluations/input-selection-agent-skills.md) preserves
the old-skill baseline, initial attempts, corrections, and fresh repeats using
the installed gem's exported skills. The first attempts exposed an invalid
baseline collected before its specification existed and an unauthorized
production fix in a test-only task. Both attempts remain visible.

After guidance corrections, a fresh scoped-adoption actor imported its boolean
from RBS, recorded a valid 1/2 baseline, and added an independently justified
assertion to reach a fresh passing 2/2 report. A fresh pressure actor preserved
the declared scope and production code, added a failing regression, and
reported the defect: **4/4 obligations exercised, `tests_passed: false`**.
Coverage and passing assertions are separate evidence.

These are small guided scenarios with supplied requirements, selectors and a
command recorder. They do not establish general agent reliability or automatic
client skill discovery.

## Limits

Complete collection and 100% exercise apply only to analyzed marginal input
obligations. Excluded arguments may affect behavior; an exclusion reason does
not prove that they are irrelevant. This feature does not analyze outputs,
assertion adequacy, combinations, arbitrary objects, strings, argument omission
or additional method shapes. Existing serial collection and RBS 4.2.0 limits
remain. Obtain fresh runtime evidence after changes even when IDs and digest
match an older report.
