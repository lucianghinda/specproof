# RBS finite string literal example

This example imports `country: ("ro" | "de")` and `expedited: bool` from the
explicit RBS signature. The DSL declares only that every combination is
allowed; it does not duplicate either input. The independent
[requirement](requirements.md) says `build` preserves the requested country and
uses `express` exactly when expedited is true.

Run from the gem directory. The RBS parser is in the optional `Gemfile.rbs`
bundle. Each command starts a fresh Ruby process and writes its report under
`tmp/`:

```sh
BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -Ilib exe/specproof plan examples/rbs_string_literals/specification.rb --rbs examples/rbs_string_literals/sig/delivery_options.rbs --target 'DeliveryOptions#build' --criterion pairwise-finite-v1 --format json
BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby examples/rbs_string_literals/test_delivery_options.rb
BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -Ilib exe/specproof suggest examples/rbs_string_literals/specification.rb --rbs examples/rbs_string_literals/sig/delivery_options.rbs --target 'DeliveryOptions#build' --report tmp/rbs-string-baseline.json --format json
SPEC_PROOF_REPORT=tmp/rbs-string-complete.json CHECK_GAP=1 BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby examples/rbs_string_literals/test_delivery_options.rb
```

The first coverage run passes three requirement-backed calls: `ro` with each
boolean value and `de` with false. Its fresh report leaves the pair
`country: "de", expedited: true` unobserved. `suggest` proposes that allowed
assignment; the suggestion supplies an input only, with no expected result.
The final fresh run adds a separate assertion justified by the requirement and
exercises the missing assignment. The example uses the correct implementation
throughout; it demonstrates a coverage gap without manufacturing a behavior
defect. Inspect both reports' run IDs, digests, completion, integrity, test
results, and input scope.

RBS `String` is unrestricted and remains unsupported. A selected union with an
unsupported member also fails atomically. Return types do not provide an
expected-result oracle. Finite-string support is feature-specific, not
guaranteed by a `0.1.x` version number; confirm typed string obligations in a
fresh plan from the installed build.
