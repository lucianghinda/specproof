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
  input :age, range: 0..120, exhaustive: true, disjoint: true do
    partition :minor, range: 0...18
    partition :adult, range: 18..120
  end
end
```

The declaration is executable Ruby. Use it only for trusted specification files. SpecProof does not resolve or autoload the declared application targets during offline analysis; the declaration file itself can execute any Ruby its author writes. Integer ranges are inclusive at both ends unless written with `...`; finite domains accept only `nil`, booleans, integers, and symbols.

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
instance-method targets. Add only behavioral bounds and partitions that the
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

The optional adapter records calls to directly owned public instance methods with named required or optional positional/keyword parameters. By default, analyze every parameter, including optional ones. A deliberately partial input scope must explicitly exclude every other named parameter with `exclude_input :name, reason: "..."`, and at least one input must remain analyzed. It observes effective bound scalar values at method entry after Ruby applies defaults; an omitted argument and an explicitly supplied equal value exercise the same obligation. A default that raises before entry contributes no entry observation. Rest, keyword-rest, forwarding, and explicit block parameters remain unsupported.

When only some parameters have finite input domains, you may explicitly exclude
the remaining named parameters with a reason. The declaration must still account
for every name in the runtime signature: each parameter is either analyzed or
excluded. Excluded values are not read by the collector. In particular, an
excluded object such as a `Hash` can coexist with selected scalar coverage,
while an object-valued selected input still makes collection incomplete. This
scope says nothing about excluded values or behavior involving their content.
See the runnable [input selection example](examples/input_selection/README.md).

It observes the selected owner's method definition during the original test run in the same process and thread. Calling an alias of that definition counts; a subclass override counts only when it calls the selected definition through `super`. Aliased target declarations and inherited target declarations are unsupported. It does not replay tests, capture return values, inspect assertions, infer defaults, or infer expected outcomes. A non-primitive effective value for an analyzed input makes collection incomplete, even if it comes from an optional default.

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

Reports distinguish exercised, not-observed, and unknown obligations; the `missing` summary lists the unobserved obligations. Missing values are informational unless `fail_on_missing: true` is selected. Reports identify their run, state whether collection completed, and use `obligation_hits` evidence with `replay: false`. JSON values include a type; integer values are decimal strings so large integers remain exact. Offline check/plan and runtime reports identify `scope.completeness_scope: "analyzed_inputs"` and list analyzed and excluded names in `scope.input_scope`. Human reports disclose excluded names and reasons. A matching set of obligation IDs does not establish matching scope: compare a fresh report's digest and input scope. `100%` means all candidates for analyzed inputs were exercised; excluded inputs, behavior, output, and interactions are not covered.

## Scope and limits

SpecProof currently focuses on bounded integer ranges and finite primitive values. The opt-in RBS reader supports only explicitly selected scalar signatures and rejects unsupported types rather than guessing. It does not analyze floats, time values, arbitrary objects, stateful or multi-call behavior, or SMT-based constraints. Specifications are trusted Ruby code; do not load declarations from untrusted sources. Collection adds an observation hook to selected application methods during the test run, so inspect the report as supporting evidence rather than as a semantic proof.

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

## Development

Run the test and lint tasks with `bundle exec rake`. The default task runs Minitest and RuboCop. The CI matrix covers Ruby 3.3, 3.4, and 4.0.

To reproduce the small baseline and instrumented timing comparison, see [docs/benchmark.md](docs/benchmark.md).

## License

SpecProof is released under the MIT License. See [LICENSE.txt](LICENSE.txt).
