# SpecProof

SpecProof checks a small, explicit contract about a Ruby method's inputs. It can find gaps or overlaps in declared input partitions, propose boundary-focused example values, and report which proposed values an existing Minitest suite actually passed to a method.

SpecProof is an aid for reviewing test gaps. It does not prove application behavior, generate tests, infer expected results, or claim that a passing test suite establishes correctness.

Use the `SpecProof` namespace in new code. The previous `Specproof` constant remains an alias.

## Install

SpecProof requires Ruby 3.3 or newer and has no runtime gem dependencies. This release is tested on CRuby 3.3, 3.4, and 4.0. Add it to an application's Gemfile from the distribution source your project uses. Runtime Minitest collection is optional and supports Minitest 5.27.x on those CRuby versions; keep Minitest in the application's test group.

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

## Observe an existing Minitest suite

The optional adapter records only calls to directly owned public instance methods that have required positional or required keyword parameters. It observes the selected owner's method definition during the original test run in the same process and thread. Calling an alias of that definition counts; a subclass override counts only when it calls the selected definition through `super`. Aliased target declarations and inherited target declarations are unsupported. It does not replay tests, capture return values, inspect assertions, or infer expected outcomes.

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

Reports distinguish exercised, not-observed, and unknown obligations; the `missing` summary lists the unobserved obligations. Missing values are informational unless `fail_on_missing: true` is selected. Reports identify their run, state whether collection completed, and use `obligation_hits` evidence with `replay: false`. JSON values include a type; integer values are decimal strings so large integers remain exact. Unsupported signatures and inputs outside a declared domain do not count as evidence.

## Scope and limits

SpecProof currently focuses on bounded integer ranges and finite primitive values. It does not analyze floats, time values, arbitrary objects, imported types, stateful or multi-call behavior, or SMT-based constraints. Specifications are trusted Ruby code; do not load declarations from untrusted sources. Collection adds an observation hook to selected application methods during the test run, so inspect the report as supporting evidence rather than as a semantic proof.

## Agent skills

The gem includes two optional skills for authoring specifications and reviewing test gaps. Export them only to an explicit client directory:

```sh
bundle exec specproof skills export --to .agents/skills
```

The exporter reports the files it writes and refuses conflicting destination content. See [docs/agent-skills.md](docs/agent-skills.md) for their purpose and use.

Try “Use specproof-specify to check whether these age partitions cover their declared range” or “Use specproof-test-gaps to find missing boundary inputs and add tests justified by the supplied eligibility rules.” See the [behavioral evaluation record](docs/evaluations/agent-skills-v0.1.md) for observed outcomes and limits.

## Development

Run the test and lint tasks with `bundle exec rake`. The default task runs Minitest and RuboCop. The CI matrix covers Ruby 3.3, 3.4, and 4.0.

To reproduce the small baseline and instrumented timing comparison, see [docs/benchmark.md](docs/benchmark.md).

## License

SpecProof is released under the MIT License. See [LICENSE.txt](LICENSE.txt).
