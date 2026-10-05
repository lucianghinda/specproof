# Pairwise coverage by integer partitions

This example declares an age range split into the complete, non-overlapping
categories `minor` (`0...18`) and `adult` (`18..120`), plus the finite country
values `"ro"` and `"de"`. All combinations are allowed. The independent
[requirement](requirements.md) says eligibility requires age 18 or older and
does not depend on country.

Run from the `gems/specproof` directory with the prepared Ruby and bundle for
this checkout. Reports and suggestion output go under `tmp/`:

```sh
bundle exec ruby -Ilib exe/specproof plan examples/pairwise_partitions/specification.rb --criterion pairwise-partitions-v1 --format json
bundle exec ruby examples/pairwise_partitions/run.rb initial
bundle exec ruby -Ilib exe/specproof suggest examples/pairwise_partitions/specification.rb --report tmp/pairwise-partitions-initial.json --format json > tmp/pairwise-partitions-suggestions.json
bundle exec ruby examples/pairwise_partitions/run.rb complete
```

The plan has four category-pair obligations: minor/adult crossed with each
country. Its typed partition values include a name and inclusive bounds, such
as `{ "kind": "partition", "name": "minor", "lower": "0", "upper": "17" }`.
The initial process passes three requirement-backed calls and leaves
minor/`"de"` unobserved. `suggest` reads the criterion from that validated
coverage report and proposes the concrete input `age: 0, country: "de"` using
the partition's lower endpoint. The suggestion supplies an input only. The
complete process adds a separate assertion, justified by the under-18 rule,
and exercises all four category pairs.

Category coverage counts any in-domain age in the declared category. It is not
boundary-value coverage, does not establish equivalence within a category, and
does not infer expected outputs. The assertion oracle remains the separate
requirement. Existing `pairwise-finite-v1` and scalar plans retain their
behavior; this criterion supports only integer ranges with explicit complete,
non-overlapping partitions and `all_allowed: true`.
