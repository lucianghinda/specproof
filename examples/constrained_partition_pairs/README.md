# Constrained pairwise coverage over integer partitions

This example combines the complete, non-overlapping age categories `minor`
(`0...18`) and `adult` (`18..120`) with finite account and country values. Its
[independent requirements](requirements.md) prohibit minors from having a
business account and define eligibility from age alone. The restriction uses
`in_partition(:minor)` to select the whole integer category:

```ruby
combinations :age, :account, :country do
  forbid age: in_partition(:minor), account: "business"
end
```

Run from the `gems/specproof` directory with the prepared Ruby and bundle for
this checkout. Reports and suggestion output go under `tmp/`:

```sh
bundle exec ruby -Ilib exe/specproof plan examples/constrained_partition_pairs/specification.rb --criterion pairwise-partitions-v1 --format json
bundle exec ruby examples/constrained_partition_pairs/run.rb initial
bundle exec ruby -Ilib exe/specproof suggest examples/constrained_partition_pairs/specification.rb --report tmp/constrained-partition-pairs-initial.json --format json > tmp/constrained-partition-pairs-suggestions.json
bundle exec ruby examples/constrained_partition_pairs/run.rb complete
```

The two integer categories and two finite domains produce eight possible full
assignments. The requirement-backed restriction removes the two assignments
with a minor and a business account, leaving six allowed tuples. The plan has
eleven required category-pair obligations and one `excluded_pairs` entry with
`reason: "no_allowed_completion"`. The initial process passes three requirement-
backed calls and hits nine obligations. `suggest` proposes the two remaining
allowed assignments, `age: 18, account: "business", country: "de"` and
`age: 0, account: "personal", country: "de"`. The complete process adds those
calls with expected results justified by the separate requirement.

The normalized selector value used for the contract digest is
`{ "kind": "partition_reference", "name": "minor" }`. Planned pair values
continue to use the existing partition object with its name and inclusive
bounds. Suggestions choose each partition's lower endpoint as a concrete call
input. Neither category coverage nor a suggested input establishes boundary
coverage or an expected result.
