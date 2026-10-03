# RBS scalar integration results

The approved [plan](superpowers/plans/2026-10-02-rbs-scalar-integration.md), commit `49a233a`, is implemented on `implement/rbs-scalar-integration` in the isolated `tmp/worktrees/rbs-scalar-integration` worktree. The original checkout remains on `implement/first-usable-release`. No push, publication, or merge is included.

## Delivered behavior

An optional RBS 4.2.0 reader imports explicitly selected, directly declared public class-instance input signatures. Scalar type facts compose with existing DSL domains; checking, planning, and collection consume the source-neutral IR. Finite inputs work without duplicate declarations; unrestricted integers require behavioral refinements. Unsupported selected types fail atomically with named limitations.

Refinements may narrow imported types, but incompatible admitted values remain visible. Checking reports a concrete witness and both declaration sources; planning rejects conflicts. Integer compatibility checks scan declared members rather than enumerating ranges, including integers beyond machine width. Equivalent compiled contracts retain existing obligation IDs, criterion, and behavioral digest.

Public loading, repeatable CLI `--rbs`/`--target` options, and Minitest installation accept the same source selection. Reports distinguish canonical supplied declarations from all resulting runtime targets. Preparation failures preserve original tests and mark analysis incomplete. Collection observes effective bound values; argument omission and output behavior are not measured.

For a target selected from RBS, extra DSL input names raise
`rbs_input_mismatch` before planning, with both declaration locations. This
adapter-level check preserves generic composition of partial type facts.
Unselected DSL targets and correctly named partial refinements remain valid.

The core gem retains **zero runtime dependencies**. The default Gemfile and lockfile are unchanged. RBS lives in the opt-in `Gemfile.rbs`; core checks/plans and skill export work without it.

## Implementation slices

| Task | Result |
| --- | --- |
| 1 | `765db3e`: immutable scalar constraints/facts, provenance, nonenumerating interval checks |
| 2 | `c4dd0e3`: composition, duplicate rejection, conflict checking, shared planning |
| 3 | `ae121b2`: real-parser reader and private projector with explicit supported shapes |
| 4 | `b465d5c`: public API/CLI, RBS-only and mixed loading, API signatures |
| 5 | `53b379d`: Minitest source integration, declaration scope, preserved failure lifecycle |
| Review fix | `c0d32ad`: reject absent selected-RBS input bindings before offline planning |
| 6 | `fbe97f6`: Registration example, updated packaged skills, package isolation, six fresh Luna evaluations |
| 7 | Separate CI lane, three-Ruby matrix, unchanged-RBS project pilot, manifests and final audit |

Code slices received independent Luna specification and quality reviews. Scalar constraints live with their operations in `type_constraints.rb`; input facts and generic provenance remain in `model.rb`. A private projector separates AST conversion from reader orchestration. These are file-placement adjustments. No generic adapter registry, nominal domain system, solver, generated DSL, or default evaluator was introduced.

Changed core files are `lib/specproof.rb` and
`lib/specproof/{model,type_constraints,composer,checker,planner,report,loader}.rb`.
Integration files are `lib/specproof/sources/{rbs,rbs_projector}.rb`,
`lib/specproof/{cli,minitest}.rb`, `sig/specproof.rbs`, `Gemfile.rbs`, its lockfile,
and `.github/workflows/main.yml`. Regression coverage is in the scalar/composer
tests, `test/rbs/`, and `test/packaging_test.rb`. Packaged workflows and evidence
live in `skills/`, `examples/rbs_registration/`, and the linked documentation.

## Verification

| Check | Actual result |
| --- | --- |
| Default Ruby 4.0.1 `bundle exec rake` | 156 tests, 786 assertions; zero failures/errors/skips; 95 files linted, no offenses |
| `ruby bin/check` | Syntax, skill/package checks and real gem build passed; focused 2 tests, 76 assertions |
| Focused runtime regression | 47 tests, 376 assertions; zero failures/errors/skips |
| CRuby 3.3.6 / 3.4.7 / 4.0.1 | Each core 156 tests/786 assertions; optional RBS 39 tests/396 assertions; zero failures/errors/skips |
| API declarations | Optional-bundle `rbs -I sig validate` passed |
| Package and skills | Real installed gem outside checkout; parser-free core CLI, idempotent export and conflict preservation passed |
| Guided Luna tasks | Six observed outcomes matched supplied requirements; exact exported skills and 17 installed library files audited |

[Compatibility and pilot evidence](pilots/rbs-v0.1/README.md) retains exact commands, raw matrix logs, isolated environments, package versions/paths, and published package hashes. [Agent evaluation evidence](evaluations/rbs-agent-skills-v0.1.md) retains rules, reports, actions, edited files, and archive manifests. Newly added prose-matching tests were removed during review; existing structural skill checks, package checks, and actual behavioral evaluations provide verification.

## Distinct demonstrations

**Shipped example.** [Registration](../examples/rbs_registration/README.md) imports integer age and nullable boolean consent, declaring only age bounds/partitions. Its independent rule requires age at least 18 and true consent. Baseline tests pass with 8/9 marginal obligations; the added boundary assertion fails against `age > 18` while 9/9 inputs are hit; the corrected implementation passes with a fresh 9/9 report. Checkpoints retain identical IDs/digest and distinct UUIDs. Nine marginal values do not mean nine combinations or output conformance proof.

**Guided agent tasks.** Six fresh Luna actors used installed-gem exported skills for finite RBS-only authoring, partial refinement, conflicts, unsupported unions, stale evidence, and a justified boundary fix. The boundary actor's RED assertion stopped its remaining examples, giving 5/9 before a final passing 9/9 run. The stale actor rejected an old passing 9/9 report despite matching input identity, then reported the actual fresh age-18 failure and 5/9 evidence. These differ from the shipped example's separate-test RED run. Explicit selectors and a command helper were supplied; this is not a client-discovery or general reliability claim.

**Existing RBS adoption.** BranchProof commit `85611af97461d1714bffffff42a4719952b9cbc4` supplies the unchanged `Branchproof::ComparisonReport#exit_code` signature. RBS-only planning yields two boolean obligations; the unchanged focused test passes 2 tests/8 assertions and exercises both. All 59 snapshot files match original source hashes. No test or gap was manufactured, and no full BranchProof suite result is claimed. Rejected candidates from the seven-location survey are documented separately.

## Remaining limits

Only verified RBS 4.2.0 is supported. Inputs are booleans, nil, supported primitive literals (including finite string literals), supported unions/optionals, and resolved built-in Integer with explicit refinement where needed. Unrestricted `String`, nominal objects, aliases, generics, collections, overloads, inherited/singleton/generated methods, rest/block/unnamed forms, and zero-input targets remain excluded. A selected union containing an unsupported member fails atomically. RBS return types are ignored and provide no expected-result oracle. Full RBS arity/order/subtyping conformance, omission coverage, nullable interval domains, automatic discovery, Sorbet, state analysis, and SMT reasoning remain separate work.

### Finite RBS strings

The finite-string extension accepts RBS string literals, their supported finite
unions, and optional forms. These reuse the exact finite-string input domain:
strings remain distinct from same-spelling symbols, and no text normalization
is performed. An unrestricted `String` input is still outside the adapter's
finite scenario model. Return types remain ignored, so expected results must
come from an independent requirement. See the [compact DeliveryOptions example](../examples/rbs_string_literals/README.md).

Matching digests establish equivalent normalized behavioral input contracts, not current implementation text or correctness. Obtain fresh runtime evidence after any source change. Historical evaluation and pilot artifacts remain unchanged; their original hashes are audited separately. Final independent specification/quality review and evidence audit are recorded in the concluding commits.

The [independent final audit](pilots/rbs-v0.1/independent-final-audit.json)
verified archive/member hashes, all 17 installed library files, four skill
assets, fresh report identity/scope, three-Ruby logs, published package hashes,
and 59 unchanged pilot source files. All [125 historical artifact hashes](pilots/rbs-v0.1/historical-original-sha-map.json)
remain unchanged. Final specification and quality reviews approved the
input-binding correction and remaining scope; no known blocker remains.
