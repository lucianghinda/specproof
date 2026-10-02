# RBS Scalar Integration Implementation Plan

> **For agentic workers:** Use `superpowers-ruby:subagent-driven-development` with Luna implementers and independent specification/quality reviews, or `superpowers-ruby:executing-plans`. Follow the workspace AGENTS.md, write utility scripts in Ruby, and execute the checkboxes task by task.

**Goal:** Reuse explicitly selected RBS input signatures, add only missing behavioral refinements, and produce the same explainable input obligations and runtime evidence as the existing DSL.

**Architecture:** An optional RBS reader emits immutable scalar type facts. A source-neutral composer combines these with DSL declarations into the existing domain IR, extended with type constraints and provenance. Checker, planner, and collector consume that IR without inspecting RBS AST nodes.

**Tech stack:** Existing CRuby 3.3/3.4/4.0, Ruby standard library, existing optional Minitest adapter, and an opt-in RBS parser supplied by the host/test bundle. Begin with RBS 4.2.0, whose installed API was inspected and probed during planning. The core gem retains zero runtime gem dependencies.

**Status:** Implementation-ready plan; no implementation changes made in this planning task. Base gem commit: `5db54bb` on `implement/first-usable-release`. Paths below are relative to `gems/specproof` unless explicitly described otherwise.

---

## 1. Useful checkpoints

1. **RBS alone supplies finite inputs.** A selected signature with `bool`, `nil`, or supported literals/unions produces a useful plan without a duplicate DSL declaration.
2. **RBS plus DSL supplies richer inputs.** RBS provides `Integer` and another finite parameter; the developer declares only an integer range and partitions. Existing consumers produce the same obligations as a fully explicit DSL contract.
3. **Conflicts remain visible.** If a behavioral domain admits a value excluded by its imported type, checking reports that value and both declaration locations. No value is silently removed.
4. **An agent closes a justified gap.** Updated exported skills reuse a supplied signature, inspect a fresh report, and add an assertion grounded in an explicit behavior rule.

The [first-release roadmap](../../../../../docs/superpowers/plans/2026-10-02-first-usable-release.md) puts type imports after the usable explicit-declaration slice. The [ecosystem analysis](../../../../../docs/2026-10-02-ecosystem-leverage-analysis.md) identifies declaration supply and the scalar ceiling as separate constraints. This milestone improves declaration supply; object domains remain separate work.

## 2. Scope and decisions

| Support now | Explicit limit |
| --- | --- |
| Explicit `.rbs` files and explicit instance-method targets | No automatic repository discovery, collection installation, or application loading |
| Direct class declarations, including nested namespaces and class reopenings | No inherited methods, modules used as runtime owners, singleton targets, aliases, or generated attributes |
| One directly declared method signature per selected target | Overloads and multiple declarations of that selected method are rejected, including equivalent duplicates |
| Named required/optional positional and keyword parameters | Unnamed positionals, rest, keyword-rest, forwarding, and blocks are rejected; no parameter-name guessing |
| `bool`, `nil`, integer/symbol/boolean literals, finite unions and optional finite types | Strings, nominal objects, records, collections, type aliases, type variables, intersections, and `untyped` are rejected for selected inputs |
| Resolved built-in `::Integer`, including unions with supported finite arms, with an explicit representable refinement | No invented values or finite coverage for unrestricted `Integer` |
| DSL ranges, finite values, and partition policies already supported | No nullable interval domain, new testing criterion, or inferred partition policy |
| Input type facts and their provenance | Return types are parsed but not analyzed; this does not establish RBS implementation conformance |

An optional parameter marker and a nullable type are different: optional means the argument can be omitted; `bool?` admits `nil`. The existing collector still measures effective bound values after Ruby defaults. No omission obligations or default-expression evaluation are introduced.

The user approved a bounded RBS milestone: reuse types, preserve provenance, expose contradictions, maintain shared obligations, and update agent skills. The concrete restrictions above are engineering choices for this first slice. Deferred capabilities must be visible in documentation and selected-target diagnostics.

### Dependency policy

- Do not add RBS to `specproof.gemspec` or the default development Gemfile.
- Add an explicitly optional `Gemfile.rbs` for the adapter test lane, using `eval_gemfile "Gemfile"` and `gem "rbs", "4.2.0", require: false`. Its lockfile records the real package and transitive dependencies.
- Consumers who select RBS add RBS to their own bundle. `require "specproof"`, DSL-only checks/plans, and skill export must work when RBS is absent.
- Lazy-load `specproof/sources/rbs` only when `rbs:` is nonempty. Fail with `rbs_dependency_missing` or `unsupported_rbs_version` when that optional path cannot use the supported parser.
- Support only the verified 4.2.0 parser initially. Broadening the range requires another compatibility test; do not assert support for an untested parser AST.

## 3. Public workflow

Use this complete positive example for documentation and end-to-end tests:

```rbs
class Registration
  def eligible?: (age: Integer, ?consent: bool?) -> bool
end
```

```ruby
# specifications/registration.rb
SpecProof.define "Registration#eligible?" do
  input :age, range: 0..120, exhaustive: true, disjoint: true do
    partition :minor, range: 0...18
    partition :adult, range: 18..120
  end
end
```

The composed domain is age `0..120` with the two declared partitions, plus consent `[nil, false, true]`. The existing criterion yields nine marginal value obligations: six age values and three consent values. It does not establish nine combinations or expected method outcomes.

```ruby
specifications = SpecProof.load(
  ["specifications/registration.rb"],
  rbs: ["sig/registration.rbs"],
  targets: ["Registration#eligible?"]
)
```

```sh
bundle exec specproof check specifications/registration.rb --rbs sig/registration.rbs --target 'Registration#eligible?' --format json
bundle exec specproof plan specifications/registration.rb --rbs sig/registration.rbs --target 'Registration#eligible?' --format json
```

`--rbs` and `--target` are repeatable. With RBS alone, `SpecProof.load([], rbs: [...], targets: [...])` and a CLI invocation with no positional DSL files are valid. A missing/empty target selector for RBS is an error. A selector without RBS is also an error. Paths and selectors are normalized and sorted; semantic duplicates of file paths/selectors are rejected as configuration errors rather than processed twice.

```ruby
SpecProof::Minitest.install!(
  specifications: ["specifications/registration.rb"],
  rbs: ["sig/registration.rbs"],
  targets: ["Registration#eligible?"],
  output: "tmp/specproof-coverage.json"
)
```

Existing calls without the new keywords retain their behavior. Selected RBS targets are composed with all supplied DSL targets; a DSL target need not appear in RBS. The collector still requires the resulting declarations to name every Ruby parameter exactly. RBS positional labels are deliberately treated as declared input bindings in this slice; no label is recovered from implementation code. Exact RBS arity, optionality, parameter ordering, outputs, and subtyping conformance are not claimed.

## 4. Core records and semantic rules

### Source-neutral facts

Add these immutable records in `lib/specproof/model.rb`; constructors must normalize/freeze their contents using existing scalar validation:

```ruby
# integer_any admits every supported Ruby Integer.
# values contains only nil, booleans, integers, and symbols.
ScalarTypeConstraint = Struct.new(:integer_any, :values, keyword_init: true)
InputTypeFact = Struct.new(:target, :input, :constraint, :source, keyword_init: true)
```

`ScalarTypeConstraint` is a closed union of unrestricted integers and exact primitive values, not a Ruby class reference. Canonicalization deduplicates and sorts values with `Domains.sort_key`; when `integer_any` is true, redundant integer literals are removed. Union combines the boolean flag with OR and finite members with set union. Unsupported AST arms never reach this representation.

Extend `Source` with `kind:` defaulting to `"dsl"`; RBS facts use `"rbs"`. Preserve `.path` and `.line`. Extend `Input` with `type_constraint: nil` and `type_sources: []`; retain `.source` as the primary domain declaration and expose `.sources` as its deterministic, deduplicated union with type sources. DSL-only inputs have exactly their existing domain and provenance, with the additive source-kind field.

For an RBS-only input, `.source` is its first canonical type source and also appears in `type_sources`; `.sources` deduplicates it. An RBS-only `Specification.source` is the first canonical source among its input facts. Canonical source order is `[path, line, kind]`. Every compiled input and target therefore retains a non-nil primary source for existing consumers.

Keep `Specification`, integer/finite domains, partitions, obligation IDs, and `input-basics-v1`. There is no generic adapter registry, RBS AST in the IR, nominal-domain family, or solver layer.

### Composition and conflict checking

`Composer.compose(specifications:, type_facts:) -> Array[Specification]` groups facts by target/input. It fills absent finite inputs, retains DSL domain/partition declarations, and attaches imported type constraints and their sources. It never overwrites an existing DSL target silently; the existing loader still rejects duplicate DSL declarations.

1. A DSL domain defines the developer's admissible behavioral input domain. An imported type constrains that declaration. It is valid for the DSL domain to be narrower than the imported type.
2. Check that **every** value in the DSL domain is admitted by the imported type. Do not replace it with the intersection: `[true, :unexpected]` against `bool` is a conflict, even though the intersection is nonempty.
3. Preserve a well-formed conflicting input in the IR. `SpecProof.check` produces `type_domain_conflict` with a deterministic incompatible-value witness and both sources; `SpecProof.plan` raises the existing `InvalidSpecificationError`. CLI check/plan exit 1 for this semantic defect.
4. With no DSL domain, a wholly finite imported constraint becomes a `FiniteDomain` with no partitions or partition promises.
5. With no DSL domain, `integer_any: true` produces `domain_refinement_required`, a configuration limitation with source/target/input context; do not fabricate endpoints or partial obligations.
6. A union containing `Integer` can be refined by existing finite values or an integer range. A range that intentionally excludes `nil` from `Integer?` is a narrower declared behavioral domain; document that consequence. To retain both `nil` and bounded integers, this release requires explicitly finite values. A general nullable interval remains deferred.
7. Reject a selected input with any unsupported union arm, even when a supplied refinement would happen to avoid that arm. No partial type import.
8. Type imports do not synthesize output contracts, behavior rules, or partitions. An empty imported finite domain is an ordinary semantic empty-domain finding, not a successful empty plan.

### Exact checking without enumeration

Create `lib/specproof/type_constraints.rb` with these operations:

```ruby
TypeConstraints.include?(constraint, value) # strict primitive identity
TypeConstraints.finite_domain(constraint)   # FiniteDomain, or nil if unbounded
TypeConstraints.first_excluded(constraint, domain) # witness, or NO_EXCLUSION
```

Define `TypeConstraints::NO_EXCLUSION = Object.new.freeze`, distinct from every supported primitive. Both `nil` and symbols can themselves be excluded witnesses. For a finite domain, scan canonically ordered members. For an integer range, `integer_any` admits the entire interval. Otherwise, scan only the constraint's sorted integer members with a cursor starting at the lower bound; return the first gap, without expanding the range. Empty domains are handled by existing checker rules. Tests must include a range with endpoints beyond 64-bit integers and confirm bounded work proportional to declaration size.

### Identity and report contract

- Preserve obligation ID construction and criterion exactly. Equivalent compiled domains/partitions produce identical IDs and reasons, whether declared in DSL or imported from RBS.
- Preserve `Report.digest` as the fingerprint of normalized behavioral domains and partition policies. Type constraints are validated against those domains but broader accepted types do not change this digest. Locations, filenames, parser version, and source kind stay outside it.
- Explicitly document that this digest does not fingerprint all source text, the full RBS signature, or implementation conformance. A fresh run is required after any input source changes.
- Add `kind` to serialized provenance under schema 1. Make the compatibility rule explicit in report docs: source objects require `path` and `line` but permit additional fields, and consumers must tolerate unknown fields. This unpublished report contract has no closed-object JSON schema; the field addition does not rename or reinterpret existing fields. Aggregate all contributing type/domain locations on obligations and relevant conflict findings; moving a declaration changes provenance but not identity.
- Add `declaration_sources` to coverage scope, listing canonical supplied DSL/RBS paths and explicit imported targets. Keep existing `scope.targets` for the resulting runtime targets. This is invocation context, not a claim that every test file was loaded.

## 5. RBS reading boundary

Create `lib/specproof/sources/rbs.rb` with `SpecProof::Sources::RBS.load(paths:, targets:) -> Array[InputTypeFact]`.

Use the installed parser and its name resolver. Load bundled RBS core signatures plus exactly the supplied `.rbs` files into an RBS environment. Do not load Ruby files, resolve application constants, fetch collections, or search arbitrary installed gem signatures. Keep selected method discovery restricted to supplied-file declarations, even though core declarations participate in name resolution.

Filter eligible declarations by the canonical source-buffer path in the supplied-file set before matching selected owner/method pairs. The environment's `class_decls` collection includes core entries and is not itself the eligible-target set.

These RBS 4.2.0 calls were verified locally during planning:

```ruby
buffer = ::RBS::Buffer.new(name: Pathname(path), content: File.read(path))
buffer, directives, declarations = ::RBS::Parser.parse_signature(buffer)
environment = ::RBS::Environment.from_loader(::RBS::EnvironmentLoader.new)
environment.add_source(::RBS::Source::RBS.new(buffer, directives, declarations))
resolved = environment.resolve_type_names
resolved.class_decls.each do |name, entry|
  entry.each_decl do |declaration|
    declaration.members.grep(::RBS::AST::Members::MethodDefinition).each do |method|
      method_type = method.overloads.fetch(0).method_type
      function = method_type.type
      # Inspect shape before converting any selected parameter types.
    end
  end
end
```

The probe resolved `Shop::Policy`'s bare `Integer` to a declared `::Shop::Integer`, while explicit `::Integer` resolved to the built-in. Parameter nodes retained names, types, and one-based locations. Therefore a spelling comparison against `"Integer"` is insufficient. Only a resolved built-in `::Integer` with no type arguments becomes `integer_any`; shadowed or unresolved references are rejected.

Selected-method processing must reject generic owners/methods, effective visibility other than public, overload alternatives, overload-extension markers, duplicate method declarations, inherited-only targets, blocks, rest forms, missing positional labels, duplicate labels, and zero-input targets. Track `Public`/`Private` members in body order, starting each class declaration at public; an explicit method visibility takes precedence. A nil `method.visibility` means the surrounding visibility applies, not an unsupported method. The discovery probe above shows method extraction only; production discovery must preserve those markers. Accept required/optional positionals, trailing required positionals, and required/optional keywords when all names are explicit. Preserve existing target syntax validation by sharing the loader's predicate rather than inventing a broader target grammar.

For selected parameter AST nodes, project only `Bool`, `Nil`, supported `Literal`, `Union`, `Optional`, and resolved built-in `ClassInstance(::Integer)`. Recursively require every union member to project successfully. Reject type aliases and all other selected input nodes with `unsupported_rbs_type`. Return types may have unsupported shapes because output analysis is explicitly absent. Unrelated valid but unsupported signatures do not fail a selected finite target; syntax errors anywhere in a supplied file do fail parsing.

Normalize errors into stable configuration codes: `rbs_dependency_missing`, `unsupported_rbs_version`, `rbs_parse_error`, `rbs_target_not_found`, `unsupported_rbs_signature`, `unsupported_rbs_type`, and `domain_refinement_required`. Include selected target/input when known and actual file/line. Do not label these as missing tests.

## 6. Files and responsibilities

| File | Responsibility |
| --- | --- |
| `lib/specproof/model.rb` | Immutable type facts/constraints; additional input provenance |
| `lib/specproof/type_constraints.rb` | Exact scalar acceptance, normalization, finite projection, exclusion witness |
| `lib/specproof/composer.rb` | Join DSL inputs and type facts; emit representable final IR |
| `lib/specproof/sources/rbs.rb` | Optional parser guard, explicit discovery, name resolution, AST projection |
| `lib/specproof/loader.rb` | Shared target predicate; preserve existing DSL semantics |
| `lib/specproof.rb` | Backward-compatible composition entry point and lazy optional loading |
| `lib/specproof/checker.rb` | Source-neutral type/domain compatibility findings |
| `lib/specproof/planner.rb`, `lib/specproof/report.rb` | Aggregate provenance; preserve semantic identity |
| `lib/specproof/cli.rb` | Repeatable explicit RBS/target options and normalized diagnostics |
| `lib/specproof/minitest.rb` | Pass source options through the existing lifecycle and record scope |
| `Gemfile.rbs`, `Gemfile.rbs.lock` | Opt-in parser testing, no default/core dependency |
| `test/type_constraints_test.rb`, `test/composer_test.rb` | Exact model/composition semantics |
| `test/rbs/source_test.rb`, `test/rbs/workflow_test.rb` | Opt-in parser contract, CLI/runtime parity, missing dependency |
| `test/fixtures/rbs/` | Positive/negative named-signature fixtures, isolated from archived pilot files |
| `examples/rbs_registration/` | Behavior rule, signatures, refinement, runner, gap/correctness demonstration |
| `skills/specproof-specify/`, `skills/specproof-test-gaps/` | Typed-source authoring and fresh-report workflow |
| `sig/specproof.rbs`, README, CHANGELOG, report/skills docs | Public API, scope, examples, additive report fields |
| `.github/workflows/main.yml` | Separate core and opt-in adapter verification lanes |

## 7. Implementation tasks

### Task 1: Freeze scalar type semantics and preserve current behavior

**Files:** model/type-constraints files and tests listed above; existing model/report/planner tests.

- [ ] Write failing tests for immutable constraints, canonical union values, unrestricted integer membership, strict primitive identity, nullable finite projection, and the `nil` exclusion witness.
- [ ] Add this concrete acceptance test before implementing interval checks:

```ruby
constraint = SpecProof::ScalarTypeConstraint.new(integer_any: false, values: [0, 1, 3])
assert_equal 2, SpecProof::TypeConstraints.first_excluded(
  constraint, SpecProof::IntegerDomain.new(lower: 0, upper: 10**100)
)
```

- [ ] Implement constructors and the three type-constraint operations from section 4. Keep the interval algorithm a cursor over declared values; use existing `FiniteDomain` normalization rather than another primitive codec.
- [ ] Extend input/source records with backward-compatible defaults. Update source/report expectations only for the additive provenance field.
- [ ] Run `ruby bin/test test/type_constraints_test.rb test/domains_test.rb test/report_test.rb test/planner_test.rb`; observe an initial missing-record/method failure, then passing assertions. Existing IDs/digests remain unchanged.
- [ ] Commit with a Lore intent describing why source-neutral type facts are needed, and record the bounded non-enumeration check.

### Task 2: Compose declarations and check conflicts

**Files:** `composer.rb`, `checker.rb`, composition/checker tests, `specproof.rb` requires.

- [ ] Write a finite type-only composition test and a partial DSL test. Use facts for `flag: bool?` and `age: Integer`; declare only age `0..120`. Assert resulting inputs are age and flag, flag values are `[nil, false, true]`, and both age sources are retained.
- [ ] Write a conflict test with DSL values `[true, :unexpected]` and imported bool. Assert `SpecProof.check` returns `type_domain_conflict` with witness `:unexpected`, both typed sources, and unchanged original domain values. Assert planning raises `InvalidSpecificationError`.
- [ ] Write tests for unrestricted Integer without refinement (`domain_refinement_required`), finite integer refinement of `Integer?`, intentional range narrowing of `Integer?`, partially incompatible ranges, and unchanged DSL duplicate-target errors.
- [ ] Implement composition per section 4. Preserve `Input.type_constraint` for checker validation; do not raise a configuration error for a well-formed type/domain contradiction.
- [ ] Update checker and planner provenance aggregation. Constraint witness checks must not call arbitrary application predicates or expand integer intervals.
- [ ] Run `ruby bin/test test/composer_test.rb test/checker_test.rb test/planner_test.rb test/loader_test.rb`; verify the new regressions fail before implementation and pass afterward.
- [ ] Commit the source-neutral composition/checking slice using Lore trailers.

### Task 3: Add the optional RBS reader

**Files:** `sources/rbs.rb`, `test/rbs/source_test.rb`, fixtures, optional Gemfile/lock.

- [ ] Create the explicit optional bundle described in section 2. Install through normal Bundler using the published package; preserve actual version/path checks. No global modifications or rebuilt packages.
- [ ] Add fixtures for the complete Registration signature, a finite-only keyword method, named positional/optional/trailing positional methods, and nested namespace shadowing of Integer.
- [ ] Add negative fixtures for unnamed positionals, unsupported union arms, generic owners/methods, overloads, rest/block forms, duplicate selected methods, unresolved names, selected type aliases, class methods, private methods, missing targets, and malformed RBS. A valid unrelated unsupported method must not fail a selected supported method.
- [ ] Implement the reader boundary and parser/version guard in section 5. Use file-located errors and reject the entire selected method when any input is unrepresentable. Do not return successful partial facts after an error.
- [ ] Keep adapter tests under `test/rbs/`; existing `bin/test` and default Rake globs select only top-level test files, so the parser-free lane excludes these deliberately rather than marking them as passing skips.
- [ ] Run `BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby bin/test test/rbs/source_test.rb`; verify actual AST shape/location tests, not mocks alone. Assert exact type facts and canonical target names.
- [ ] Add a subprocess test hiding RBS from gem activation: loading the adapter fails with the named dependency error; loading the core and exporting skills still succeed.
- [ ] Commit the optional adapter, noting the supported parser version and deferred AST forms.

### Task 4: Connect public load/check/plan interfaces

**Files:** `specproof.rb`, `loader.rb`, `cli.rb`, `report.rb`, CLI/workflow tests, API signature.

- [ ] Extend `SpecProof.load(paths, rbs: [], targets: [])`. With no RBS options, call the existing loader unchanged. With RBS, allow empty DSL paths, load explicit type facts, and compose. Validate options before optional parser activation.
- [ ] Extend CLI parsing for repeatable `--rbs FILE` and `--target TARGET`; retain `--format` behavior and existing exit codes. Reject missing values, selectors without RBS, RBS without selectors, duplicate canonical selectors/paths, and unknown options.
- [ ] Add RBS-only, mixed-source, and ordinary DSL CLI tests. JSON stdout must contain one document; parser/DSL incidental output belongs on stderr as already established.
- [ ] Add semantic conflict tests expecting check/plan exit 1 and both source locations, and malformed/unrepresentable-source tests expecting exit 2 with stable codes.
- [ ] Add source equivalence tests: complete explicit DSL versus partial DSL plus RBS. Assert identical normalized domains, criterion, obligation IDs, reasons, and digest; provenance differs deliberately. Repeat after moving RBS/DSL files and lines to prove location-independent identity.
- [ ] Update API declarations to match the implemented keywords and records; validate declarations with RBS without claiming implementation type checking.
- [ ] Run `BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby bin/test test/rbs/workflow_test.rb test/cli_test.rb test/report_test.rb test/loader_test.rb`; then run the ordinary core suite without RBS activation.
- [ ] Commit the reusable public workflow with Lore compatibility and identity notes.

### Task 5: Observe the composed contract through Minitest

**Files:** `minitest.rb`, `test/rbs/workflow_test.rb`, isolated child fixtures, report-format docs.

- [ ] Extend `install!` with `rbs: []` and `targets: []`; accept empty `specifications:` only when a valid explicit RBS source selection is present. Store normalized source options and pass them to `SpecProof.load` within the existing preparation lifecycle.
- [ ] Add `scope.declaration_sources`; preserve effective-bound-value metadata, original Minitest failure handling, integrity policy, run IDs, and atomic reports.
- [ ] Use a real subprocess Registration implementation with `eligible?(age:, consent: nil)` and a separate supplied eligibility rule. Exercise all nine values with meaningful assertions. Compare offline/RBS/explicit-DSL plan IDs and runtime report IDs/digests.
- [ ] Add a gap subprocess leaving age 18 unobserved, then a fresh corrected run hitting it. Test optional consent omission and explicit nil sharing one value obligation; no omission-coverage claim.
- [ ] Add subprocess failures for missing parser, unbounded imported input, type/domain conflict, and a Ruby parameter-name mismatch. Each must preserve original test failures/exceptions and produce incomplete analysis rather than a completed partial report.
- [ ] Run `BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby bin/test test/rbs/workflow_test.rb test/minitest_integration_test.rb test/optional_minitest_integration_test.rb`.
- [ ] Commit runtime source integration separately from behavior/example changes.

### Task 6: Deliver the example and agent workflow

**Files:** `examples/rbs_registration/`, both bundled skills/reference files, README/CHANGELOG/agent/report docs, skill/packaging tests.

- [ ] Add the RBS signature and partial DSL example from section 3. Supply an explicit behavior rule explaining the age-18 eligibility boundary and the meaning of consent; tests must derive their assertions from that rule, not coverage candidates alone.
- [ ] Demonstrate three checkpoints: passing baseline with an age-18 gap; added boundary assertion failing against the supplied `age > 18` defect; corrected implementation with all nine unchanged obligations exercised in a fresh report.
- [ ] Update `specproof-specify` to inspect selected RBS signatures first, declare only absent refinements, run check before planning, and handle unsupported/unbounded types honestly. Explain that optional arguments and nilability are distinct.
- [ ] Update `specproof-test-gaps` to validate the imported-target/source scope, fresh UUID, completed integrity, tests passed, digest/IDs, and intended test filter. RBS parameter types never supply behavioral output assertions.
- [ ] Run installed-gem export tests, idempotence/conflict checks, and package checks with and without the optional parser. Preserve old evaluation archives and their original hashes.
- [ ] Run fresh Luna evaluations using exported skills: finite RBS-only authoring; partial refinement; contradictory refinement; unsupported union; stale report; justified boundary gap. Retain actual skills, reports, actions, and exact fixture rules. Do not claim general agent reliability from these scenarios.
- [ ] Commit example, documentation, skills, and evaluation evidence with explicit scope notes.

### Task 7: Verify optional isolation, compatibility, and adoption

**Files:** CI workflow, implementation-status document, new pilot/evaluation artifacts only.

- [ ] Run the ordinary core suite and default lint task independently of the opt-in RBS bundle. Expected baseline before changes: 131 tests and 663 assertions; final counts must be recorded from actual runs, not predicted.
- [ ] Run adapter and core regression suites on CRuby 3.3.6, 3.4.7, and 4.0.1 with published Minitest 5.26.2 and RBS 4.2.0 in explicit isolated bundles. Clear incompatible ambient gem/Bundler paths as in previous compatibility checks. A failed parser installation is a compatibility blocker, not a passing skip.
- [ ] Add separate CI lanes for core and RBS tests. Keep core tests meaningful when RBS is absent; optional adapter tests must run and fail if their expected parser is unavailable.
- [ ] Run `bundle exec rake`, `ruby bin/check`, the opt-in adapter suite, API declaration validation, and `git diff --check`. Verify built-gem operation outside the checkout and parser-free CLI/skill export.
- [ ] Survey supplied local projects for one existing supported RBS instance-method signature with a real test suite. Use an unchanged copy and its original signatures. Retain source hashes, fresh exported skills, commands, baseline/gap/final reports, and behavior-rule justification for any added test.
- [ ] If the bounded local survey finds no eligible RBS target, record the actual rejected shapes and scope. The shipped fixture must still prove the architecture; do not manufacture an existing RBS file and call it ecosystem adoption. Record this as an adoption limitation, not a reason to broaden into objects/overloads.
- [ ] Run independent Luna specification review, then quality review after findings are resolved; separately audit the pilot's scope and hashes. Do not count an agent success message as verification evidence.
- [ ] Update implementation results with actual matrix/package/skill outcomes, remaining limitations, and unchanged external sources. Commit verified work with Lore trailers; no publishing or pushing is included.

## 8. Acceptance checklist

- [ ] R01: No RBS activation or dependency is required for core DSL checks/plans, Minitest's existing DSL path, or skill export.
- [ ] R02: Explicit selected finite RBS inputs work without duplicate DSL domains.
- [ ] R03: Integer plus explicit range/partitions and automatically imported finite parameters work through every existing consumer.
- [ ] R04: RBS-only and DSL/mixed forms yield identical supported obligations/digests; provenance remains accurate and source-order independent.
- [ ] R05: Partially overlapping incompatible behavioral declarations produce located semantic conflicts, never silent intersections.
- [ ] R06: Unbounded and unsupported selected inputs produce named limitations without fabricated finite obligations or partial successful reports.
- [ ] R07: Shadowed Integer is resolved correctly; no application constant resolution, application loading, network collection lookup, or default evaluation occurs.
- [ ] R08: Overloads, unnamed inputs, aliases, generics, and unsupported signatures are rejected explicitly; valid unrelated unsupported signatures do not fail selected finite targets.
- [ ] R09: Runtime reports preserve fresh IDs, effective-value semantics, tuple integrity, original failures, and exact imported invocation scope.
- [ ] R10: The agent closes a behaviorally justified gap while using RBS to remove duplicate declarations; archived evidence remains reproducible and honestly scoped.
- [ ] R11: Core/adapter/package/skill checks and the supported Ruby matrix pass without skipped optional coverage, with actual counts recorded.
- [ ] R12: The results distinguish a shipped demonstration, genuine unchanged-RBS project adoption, and unsupported survey candidates.

## 9. Rationale and alternatives

**Chosen:** an optional AST reader, a small closed scalar type constraint, and source-neutral composition/checking. This preserves useful existing analyzers and exposes source conflicts without a new programming model.

**Rejected: generate temporary DSL from RBS.** It would lose the source-level distinction between type acceptance and behavioral refinement, complicate provenance, and risk executable generated declarations.

**Rejected: intersect all declarations silently.** A partially incompatible behavioral domain would be repaired without the developer knowing which declared cases disappeared.

**Rejected: import the whole RBS type system first.** Objects, generics, inheritance, aliases, and overload alternatives need separate semantics before consumers can derive honest obligations. Broad parsing alone would not demonstrate useful coverage.

**Future modifiers:** keep `integer_any` as a type constraint, not a finite testing domain. Keep defaults and omission distinct. New type forms must either lower soundly into supported constraints or surface a limitation. Do not weaken parser/version guards or reinterpret previous archives to improve reported adoption.

## 10. Research and planning evidence

The official [RBS syntax documentation](https://github.com/ruby/rbs/blob/master/docs/syntax.md) defines literal and union types, nullable types, booleans, and named/unnamed parameters. This plan deliberately supports a subset of those forms and does not imply complete RBS support.

Local planning used installed RBS 4.2.0 on CRuby 4.0.1. Inspected `parser_aux.rb`, `environment.rb`, `environment/class_entry.rb`, AST members, function parameters, and type nodes. A standard-library Ruby probe parsed required/optional positional and keyword parameters and confirmed nested Integer shadow resolution and parameter source lines. It also exposed the current `entry.each_decl` API, rather than assuming older `.decls` interfaces. These checks establish planning feasibility on one installed parser/runtime; the implementation matrix remains required.

A Luna design review highlighted overload alternatives, positional names, unbounded types, namespace shadowing, partial unions, provenance, and source-independent identity. The plan adopts those boundaries while rejecting silent intersection in favor of explicit type/domain conflicts.
