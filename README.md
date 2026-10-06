# SpecProof

SpecProof checks a small, explicit contract about a Ruby method's inputs. It can find gaps or overlaps in declared input partitions, propose boundary-focused example values, and report which proposed values an existing Minitest suite actually passed to a method.

SpecProof is an aid for reviewing test gaps. It does not prove application behavior, generate tests, infer expected results, or claim that a passing test suite establishes correctness.

Use the `SpecProof` namespace in new code. The previous `Specproof` constant remains an alias.

## Install

SpecProof requires Ruby 3.3 or newer and has no runtime gem dependencies. This release is tested on CRuby 3.3, 3.4, and 4.0. Add it to an application's Gemfile from the distribution source your project uses. Runtime Minitest collection is optional and supports Minitest `>= 5.26.2` and `< 5.28.0` with matching package/runtime major and minor versions; keep Minitest in the application's test group. The development bundle selects `~> 5.26.2` because the published 5.27.0 package contains a mismatched runtime version; see [compatibility evidence](docs/minitest-compatibility.md).

For development in this checkout, run commands from `gems/specproof` with `bundle exec`. To try this unpublished implementation in another application, use a local path dependency:

```ruby
gem "specproof", path: "/path/to/specproof/gems/specproof"
```

## Describe an input contract

Create a Ruby file that declares the target method and the input values it accepts:

```ruby
require "specproof"

SpecProof.define "AgePolicy#adult?" do
  input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
    partition :minor, range: 0...18
    partition :adult, range: 18..120
  end
end
```

The declaration is executable Ruby. Use it only for trusted specification files. SpecProof does not resolve or autoload the declared application targets during offline analysis; the declaration file itself can execute any Ruby its author writes. Integer ranges are inclusive at both ends unless written with `...`; finite domains accept `nil`, booleans, integers, symbols, and explicitly listed text values.

Targets can be written as canonical strings or as Ruby `Method`/`UnboundMethod`
objects. For example, `"DeliveryOptions#build"` and
`DeliveryOptions.instance_method(:build)` normalize to the same target. A
class or module singleton method uses a dot, as in `"DeliveryOptions.build"`
or `DeliveryOptions.method(:build)`. Strings are useful for offline
specifications: normalization does not load or autoload the application owner.
Method objects are convenient when the application code is already loaded;
they use Ruby reflection and do not invoke the method. The declaration-time
method must be a directly defined public method on a named class or module;
aliases, inherited singleton methods, anonymous owners, and methods bound to
arbitrary instances are unsupported. See the runnable
[method targets example](examples/method_targets/README.md) and
[verification results](docs/method-targets-results.md).

Finite strings are exact values, not a general String domain. For example, `values: [nil, 1, "user_123"]` describes three scenario values; `"user_123"` is distinct from `:user_123`. Only exact `String` instances with valid UTF-8 or US-ASCII encoding are accepted, and US-ASCII is canonicalized to UTF-8. Empty strings, whitespace, Unicode, and embedded NUL are valid; invalid bytes, other encodings, and String subclasses are rejected. Text is not trimmed, case-folded, or normalized. SpecProof uses owned snapshots without changing application strings. RBS string literals and finite unions of supported literals provide exact string scenarios; unrestricted `String` remains unsupported, and a selected union containing an unsupported member fails atomically.

`allow_gaps: false` requires every value in the input domain to belong to at
least one partition. `allow_overlaps: false` requires it to belong to at most
one. Together, every valid value belongs to exactly one partition. These rules
check the specification's grouping; they do not require testing every value.
Omitting either option permits that condition, equivalent to setting it to
`true`. Partition-based pairwise coverage requires both options to be `false`.

Existing specifications can still use `exhaustive: true` in place of
`allow_gaps: false`, and `disjoint: true` in place of `allow_overlaps: false`.
Their `false` values map to the new options' `true` values. Use only one
spelling per policy in a declaration. Equivalent spellings preserve contract
digests and obligation IDs.

Run the checker and planner:

```sh
bundle exec specproof check examples/age_policy/specification.rb
bundle exec specproof plan examples/age_policy/specification.rb
bundle exec specproof plan examples/age_policy/specification.rb --format json
```

`check` reports declared partition gaps and overlaps. `plan` reports candidate values from the `input-basics-v1` criterion, including values at the domain edges and partition boundaries. It does not claim those candidates form a complete test suite. JSON output has a versioned schema and includes source locations and a digest of the declared contract.

The age example plans `0`, `1`, `17`, `18`, `119`, and `120`. The shipping example in [examples/shipping.rb](examples/shipping.rb) shows finite domains. [examples/partition_gap.rb](examples/partition_gap.rb) is intentionally incomplete and makes `check` exit with a semantic finding.

## Reuse an explicit RBS signature

RBS can supply supported finite scalar input types for explicitly selected
instance-method and singleton-method targets. Selectors use `Class#method` for
instance methods and `Class.method` or `Module.method` for singleton methods.
Add only behavioral bounds and partitions that the
signature cannot express; an unrestricted `Integer` needs such a refinement.
For a target selected from RBS, each DSL `input` or `exclude_input` must use a
name declared in that signature. By default all named signature parameters
must be analyzed; a deliberately narrower contract accounts for each omitted
name with an explicit reasoned exclusion, and still analyzes at least one
input. A mismatch reports `rbs_input_mismatch`; other DSL-only targets can
still be supplied alongside selected RBS targets. Supported finite RBS types
remain imported without duplicate DSL inputs. An explicit exclusion can scope
out a type-only parameter, while an unsupported selected union remains an
atomic failure.
The reader supports the verified RBS `4.2.0` parser only. RBS remains an
optional dependency, so consumers who use this workflow must add it to their
own bundle:

```ruby
gem "rbs", "4.2.0", require: false
```

The core gem has no runtime gem dependencies. See
[the supported integration limits](docs/rbs-implementation-status.md). For
the opt-in adapter bundle in this checkout, the [registration example](examples/rbs_registration) combines
`sig/registration.rbs` with a DSL age refinement. Its independent
[eligibility rule](examples/rbs_registration/requirements.md) says an applicant
is eligible exactly when `age >= 18` and consent is true.

The compact [finite string example](examples/rbs_string_literals) imports
`country: ("ro" | "de")` and `expedited: bool` without duplicate DSL inputs.
Its plan includes the exact country strings. String values remain distinct
from same-spelling symbols. RBS `String` remains an unrestricted domain and is
not supported. RBS return types are ignored; expected behavior must come from
an independent requirement.

From this checkout, run the check and plan with the explicit file and target:

```sh
BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -Ilib exe/specproof check examples/rbs_registration/specification.rb --rbs examples/rbs_registration/sig/registration.rbs --target 'Registration#eligible?' --format json
BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -Ilib exe/specproof plan examples/rbs_registration/specification.rb --rbs examples/rbs_registration/sig/registration.rbs --target 'Registration#eligible?' --format json
```

The plan contains nine marginal obligations: six age candidates and three
consent values (`nil`, `false`, and `true`). They are not nine input
combinations, do not specify expected results, and do not prove output
behavior. The runnable example shows an eight-of-nine report when age 18 is
omitted, the independent boundary assertion failing against an `age > 18`
implementation, and a fresh complete report with the corrected `age >= 18`
implementation. The faulty and corrected versions are separate files and each
checkpoint runs in its own process. See the example README for exact commands.

## Observe an existing Minitest suite

The optional adapter records calls to directly defined public instance methods
and class/module singleton methods with named required or optional
positional/keyword parameters. By default, analyze every parameter, including
optional ones. A deliberately partial input scope must explicitly exclude every
other named parameter with `exclude_input :name, reason: "..."`, and at least
one input must remain analyzed. It observes effective bound scalar values at
method entry after Ruby applies defaults; an omitted argument and an explicitly
supplied equal value exercise the same obligation. A default that raises before
entry contributes no entry observation. Rest, keyword-rest, forwarding, and
explicit block parameters remain unsupported.

When only some parameters have finite input domains, you may explicitly exclude
the remaining named parameters with a reason. The declaration must still account
for every name in the runtime signature: each parameter is either analyzed or
excluded. Excluded values are not read by the collector. In particular, an
excluded object such as a `Hash` can coexist with selected scalar coverage,
while an object-valued selected input still makes collection incomplete. This
scope says nothing about excluded values or behavior involving their content.
See the runnable [input selection example](examples/input_selection/README.md).

It resolves the selected owner's canonical method name afresh when collection
starts, then observes that directly defined method during the original test
run in the same process and thread. A method object supplied at declaration
time must still describe that current direct definition; declaration and
collection both reject changed method identity. Calling an alias of the
selected definition counts; a subclass override counts only when it calls the
selected definition through `super`. Aliased target declarations and inherited
target declarations are unsupported. It does not replay tests, capture return
values, inspect assertions, infer defaults, or infer expected outcomes. A
non-primitive effective value for an analyzed input makes collection
incomplete, even if it comes from an optional default.

Add a separate test entrypoint after Minitest and your application code have loaded:

```ruby
require "minitest/autorun"
require "age_policy"
require "specproof/minitest"

SpecProof::Minitest.install!(
  specifications: ["examples/age_policy/specification.rb"],
  output: "tmp/specproof-coverage.json",
  fail_on_missing: false
)
```

The runnable [age policy example](examples/age_policy) includes a passing implementation and assertions at all six planned values. Its `faulty` variant isolates the common `age > 18` boundary defect: the five non-boundary examples pass, while the planned value `18` remains unobserved. The separate explicit boundary assertion fails against that faulty implementation. Collection remains independent of the test result; a collector integrity failure fails the run, and original Minitest failures are preserved.

Reports distinguish exercised, not-observed, and unknown obligations; the `missing` summary lists the unobserved obligations. Missing values are informational unless `fail_on_missing: true` is selected. Reports identify their run, state whether collection completed, and use `obligation_hits` evidence with `replay: false`. JSON values include a type; integer values are decimal strings so large integers remain exact. String values use `{ "kind": "string", "value": "..." }` under the existing schema version 1, so consumers must handle this additive kind explicitly. Offline check/plan and runtime reports identify `scope.completeness_scope: "analyzed_inputs"` and list analyzed and excluded names in `scope.input_scope`. Human reports disclose excluded names and reasons. A matching set of obligation IDs does not establish matching scope: compare a fresh report's digest and input scope. `100%` means all candidates for analyzed inputs were exercised; excluded inputs, behavior, output, and interactions are not covered.

## Scope and limits

SpecProof currently focuses on bounded integer ranges and finite primitive values, including exact enumerated text. The opt-in RBS reader supports only explicitly selected scalar signatures and rejects unsupported types rather than guessing. It does not analyze floats, time values, arbitrary objects, stateful or multi-call behavior, or SMT-based constraints. Specifications are trusted Ruby code; do not load declarations from untrusted sources. Collection adds an observation hook to selected application methods during the test run, so inspect the report as supporting evidence rather than as a semantic proof.

## Agent skills

The gem includes two optional skills for authoring specifications and reviewing test gaps. Export them only to an explicit client directory:

```sh
bundle exec specproof skills export --to .agents/skills
```

The exporter reports the files it writes and refuses conflicting destination content. See [docs/agent-skills.md](docs/agent-skills.md) for their purpose and use.

Try “Use specproof-specify to check whether these age partitions cover their declared range” or “Use specproof-test-gaps to find missing boundary inputs and add tests justified by the supplied eligibility rules.” See the [behavioral evaluation record](docs/evaluations/agent-skills-v0.1.md) for observed outcomes and limits.

The [optional-argument pilot](docs/optional-arguments-results.md) shows adoption on PStoreLogger and the distinction between a complete scalar scenario report and incomplete full-suite collection on object payloads.

The [RBS implementation results](docs/rbs-implementation-status.md) include
the three-Ruby matrix, [six guided agent scenarios](docs/evaluations/rbs-agent-skills-v0.1.md),
and [unchanged-signature BranchProof adoption](docs/pilots/rbs-v0.1/README.md).

The [input-selection results](docs/input-selection-results.md) show the unchanged
PStoreLogger suite collecting scoped file-ID coverage with Hash payloads,
plus agent exercises that preserve excluded-input scope and failing assertions.

The [finite-string results](docs/finite-strings-results.md) extend that pilot to
the documented `"user_123"` case, showing its missing obligation and a separate
requirement-backed assertion that exercises it.

## Pairwise finite input combinations

`input-basics-v1` remains the default scalar criterion. When a requirement
defines a finite joint scenario, declare its inputs in one `combinations`
group and explicitly choose `all_allowed: true` or list requirement-backed
`forbid` clauses. The `pairwise-finite-v1` criterion plans each pair of values
that occurs together in at least one allowed full assignment. It does not
assert expected outputs or establish that inputs are behaviorally independent.
Each analyzed input in a runtime call must still be valid before that call can
earn pairwise evidence.

The runnable [pairwise example](examples/pairwise/README.md) documents two
independent DeliveryOptions requirements and shows the faulty interaction
implementation passing three calls while missing the `expedited: true`,
`notify: true` pair. A requirement-backed assertion exposes the defect; a
separate corrected implementation then covers all four pair obligations. The
example also shows a constrained plan with three required and one excluded
pair, and a three-boolean plan with 12 pair obligations versus eight exhaustive
tuples.

Use `specproof suggest` when an intact pairwise coverage report has missing
pairs. It replans the current declarations, checks that the report matches
their exact typed obligations and recorded scope, then prints allowed full
group assignments that cover the missing pairs. Suggestions are candidates
for new tests: they are not executed, carry no expected results, and do not
fingerprint implementation or test files. Rerun the intended suite after
source or test changes. The [suggestion example](examples/pairwise_suggestions/README.md)
shows a three-of-four DeliveryOptions baseline, the `11` candidate, a separate
requirement-backed failing assertion, and a fresh corrected run. It also shows
one suggested three-boolean assignment covering several missing pairs, with
the other method inputs left for the caller to supply when outside the group.

## Pairwise coverage over integer partitions

`pairwise-partitions-v1` pairs explicitly complete and non-overlapping integer
categories with other finite inputs. It supports `all_allowed: true` or
requirement-backed `forbid` assignments that select whole integer
partitions with `in_partition(:name)` and exact finite values. Each clause
forbids matching full assignments; required and excluded pairs are derived
from whether an allowed full completion exists. An excluded pair can therefore
be impossible indirectly through a restriction on a third input. Integer
restrictions must select a whole partition; raw integer values and partial
range predicates are not supported. Finite inputs continue to use exact values.
Category coverage is not boundary-value coverage and does not assert equivalent
behavior throughout a category. The runnable [unrestricted partition
example](examples/pairwise_partitions/README.md) shows a missing minor/`"de"`
category pair. The [constrained example](examples/constrained_partition_pairs/README.md)
shows requirement-backed restrictions, an excluded category pair, and allowed
assignment suggestions. See the [initial partition results](docs/pairwise-partitions-results.md)
and [constrained partition results](docs/constrained-partition-pairs-results.md)
for verification evidence.

## Development

Run the test and lint tasks with `bundle exec rake`. The default task runs Minitest and RuboCop. The CI matrix covers Ruby 3.3, 3.4, and 4.0.

To reproduce the small baseline and instrumented timing comparison, see [docs/benchmark.md](docs/benchmark.md).

## License

SpecProof is released under the MIT License. See [LICENSE.txt](LICENSE.txt).
