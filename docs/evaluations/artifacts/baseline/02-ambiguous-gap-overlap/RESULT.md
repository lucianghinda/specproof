# Result

SpecProof reports two specification problems for `Discount#rate`:

- **Overlap:** score `25` belongs to both `low` (`0..30`) and `middle` (`25..50`).
- **Uncovered range:** scores `51..59` belong to no partition; `middle` ends at `50` and `preferred` starts at `60`.

The current Ruby implementation uses `<= 30` for `:low`, `31..50` for `:middle`, and `51..100` for `:preferred`. For example, at `25` it returns `:low`, despite the specification assigning that score to two partitions; at `51` it returns `:preferred`, though the specification leaves that score uncovered. These are implementation/specification disagreements, not a decision about which boundaries should be changed.

I made no edits. The intended policies for the overlap and gap are undecided, so please tell me how you want the `low`/`middle` boundary handled and how the `51..59` range should be covered before either policy is edited.

## Commands and results

Ran with the provided environment prefix and Ruby executable:

```text
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/discount.rb
```

Output (exit 1):

```text
partition_gap Discount#rate / score: [51, 59] (specifications/discount.rb:2)
partition_overlap Discount#rate / score: 25 (specifications/discount.rb:3, specifications/discount.rb:4)
```

Ran the same command with `plan` in place of `check`; it produced the same two diagnostics and exited 1.

Inspected `discount.rb` and `specifications/discount.rb` directly. No tests were run because no implementation was changed.
