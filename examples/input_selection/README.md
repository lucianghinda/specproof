# Explicit input selection

This example analyzes the boolean `expedited` option and explicitly excludes
the ordinary `Hash` payload. The expected results come from the independent
[delivery requirements](requirements.md), not from the implementation.

From the `gems/specproof` checkout, inspect the offline contract and candidate
plan, then run the Minitest suite:

```sh
bundle exec ruby -Ilib exe/specproof check examples/input_selection/specification.rb --format json
bundle exec ruby -Ilib exe/specproof plan examples/input_selection/specification.rb --format json
bundle exec ruby -Ilib examples/input_selection/test_delivery_policy.rb
```

The plan has one candidate for each boolean value. The suite asserts both
acceptance and rejection under the independent rules and passes ordinary Hash
values at runtime. Its coverage report concerns only the selected `expedited`
input. It says nothing about payload values, payload content, output behavior
outside the assertions, interactions, or complete method correctness. An
excluded input cannot be used to claim coverage for that input. If a selected
input receives a non-primitive value, collection is incomplete.
