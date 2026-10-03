# Pairwise input scenarios

The [requirements](requirements.md) independently say that express speed is
selected exactly when `expedited` is true, and the notification flag follows
`notify`. The input declaration describes finite booleans; it does not encode
those output rules.

Run these commands from the `gems/specproof` directory with its development
bundle:

```sh
bundle exec ruby -Ilib exe/specproof plan examples/pairwise/specification.rb --criterion pairwise-finite-v1 --format json
bundle exec ruby examples/pairwise/run.rb initial
bundle exec ruby examples/pairwise/run.rb gap
bundle exec ruby examples/pairwise/run.rb corrected
bundle exec ruby -Ilib exe/specproof plan examples/pairwise/constrained_specification.rb --criterion pairwise-finite-v1 --format json
bundle exec ruby -Ilib exe/specproof plan examples/pairwise/three_boolean_specification.rb --criterion pairwise-finite-v1 --format json
bundle exec ruby examples/pairwise/run.rb three
```

The plan has four pair obligations for the two booleans. The `initial` process
runs three independent assertions for `00`, `01`, and `10`: all three tests
pass and coverage is 3/4. The faulty method computes the notification flag as
`notify && !expedited`; it agrees with the requirement on those three cases.
The `gap` process repeats them and adds the requirement-backed `11` assertion.
That assertion fails, although all four pair obligations have now been
exercised (4/4). The `corrected` process uses a separate implementation and
passes all four assertions with 4/4 pair coverage. Each mode runs in its own
process so the implementations never coexist.

The constrained declaration has its own [requirement](constrained_requirements.md):
expedited delivery requires notification. It explicitly forbids
`expedited: true, notify: false`, so the plan has three required pairs and one
`excluded_pairs` row with `reason: "no_allowed_completion"`. This rule is not
used by the unconstrained example and must not be inferred from the faulty
implementation.

The three-boolean declaration has 12 possible pair rows. Four calls, `000`,
`011`, `101`, and `110`, exercise all 12. That is pair coverage for the three
input pairs; it does not claim all eight full tuples were run or that all
application behavior is covered.

Each runner mode writes a fresh report below `tmp/pairwise-*.json`. Compare its
criterion, digest, typed pair rows, run ID, integrity, and `tests_passed` with
the current plan and command. Coverage records method calls; the assertions
derive expected values from the separate requirements file.
