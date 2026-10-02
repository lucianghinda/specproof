# Result

The integer input domain is declared as the closed interval `0..100_000`, with disjoint partitions `standard: 0..4_999` and `free: 5_000..100_000`. These match the explicit contract in `requirements.md`. `Checkout#shipping` uses the same threshold (`cents >= 5_000`), so its behavior matches both partitions throughout the declared domain. No return-value contract is specified, so none was added. No source/requirements mismatch found.

SpecProof reported no specification findings. Its plan produced the single supported obligation, `input-basics-v1`, for `Checkout#shipping / cents`, with candidates `0, 1, 4999, 5000, 99999, 100000`. Those candidates cover the input endpoints and their in-domain neighbors plus both partition boundaries.

Commands run from this workspace:

```text
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --help
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/checkout.rb --format human
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/checkout.rb --format human
```

Results: CLI help listed `--help`, `check`, and `plan`; `check` printed `No specification findings.`; `plan` printed the `input-basics-v1` candidates listed above. No tests were run because the fixture explicitly provides no test suite or output behavior.
