# Result

The requirements are declared for `Checkout#shipping` in
`specifications/checkout.rb`. Its `cents` input domain is the closed integer
range `0..100_000`; the exhaustive, disjoint partitions are `standard`
(`0..4_999`) and `free` (`5_000..100_000`). The declarations are grounded in
`requirements.md:3-6`. The implementation's threshold at `checkout.rb:3`
matches the partition boundary for values in that domain.

The method does not validate the integer type or the domain endpoints.
Requirements describe these as the input contract and do not specify behavior
for invalid inputs, so no invalid-input behavior is asserted. No return-value
or other output behavior has been declared, as required by
`requirements.md:8`.

`specifications/checkout.rb` already contained the matching declaration, so no
source/specification edits were needed. The specification's declaration source
locations are lines 2-4.

## Verification

Commands run from this directory (using the supplied Ruby 4.0.1 and
SpecProof 0.1.0 environment):

```text
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/checkout.rb --format json
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/checkout.rb --format json
```

Check result: schema version 1, no errors, no findings. Contract digest:
`26f4b60e61f1c2010df1ce171b70654fd488bfb2b7b66a2e7a62a713be37528f`.

Plan result: criterion `input-basics-v1`, no errors, same contract digest.
Boundary candidates are `0`, `1`, `4999`, `5000`, `99999`, and `100000`.
Their reasons are respectively the input/standard lower endpoints, lower
neighbor, standard upper endpoint, free lower endpoint, upper neighbor, and
input/free upper endpoints. Each obligation points to the corresponding
declaration in `specifications/checkout.rb` (line 2 for the domain, line 3
for `standard`, and line 4 for `free`). These are planned candidates for
review, not a complete or proven test suite.

The fixture states it has no test suite; none was run.
