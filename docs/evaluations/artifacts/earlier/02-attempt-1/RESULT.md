# SpecProof result: Discount#rate

## Scope

The task asks to check the explicit input specification and inspect the Ruby implementation. The fixture says the intended boundaries are undecided and directs us to ask before editing either policy. I did not change the specification or implementation. The fixture contains no tests.

## Commands and results

Ran the installed SpecProof 0.1.0 executable with Ruby 4.0.1, the provided isolated gem environment, and plugins disabled, from the fixture directory.

`GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --help`

```text
Usage:
  specproof --version
  specproof check SPECIFICATION.rb [SPECIFICATION.rb ...] [--format human|json]
  specproof plan SPECIFICATION.rb [SPECIFICATION.rb ...] [--format human|json]
  specproof skills export --to DIRECTORY [--format human|json]
```

`GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/discount.rb --format json`

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"check","errors":[],"contract_digest":"9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1","findings":[{"code":"partition_gap","target":"Discount#rate","input":"score","witness":["51","59"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":2}]},{"code":"partition_overlap","target":"Discount#rate","input":"score","witness":"25","sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":3},{"path":"/private/tmp/specproof-agent-evaluations/with-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":4}]}]}
```

`GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/discount.rb --format json`

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"plan","errors":[],"contract_digest":"9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1","criterion":"input-basics-v1","obligations":[],"findings":[{"code":"partition_gap","target":"Discount#rate","input":"score","witness":["51","59"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":2}]},{"code":"partition_overlap","target":"Discount#rate","input":"score","witness":"25","sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":3},{"path":"/private/tmp/specproof-agent-evaluations/with-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":4}]}]}
```

The contract digest is `9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1`. Check has no errors but reports both semantic findings. Plan repeats those findings and returns no obligations, so there is no clean boundary-candidate plan to report yet.

## Findings and implementation

The declared domain is the inclusive integer range 0..100, marked exhaustive and disjoint at [specifications/discount.rb](/private/tmp/specproof-agent-evaluations/with-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb:2). The declarations place `low` at 0..30 (line 3), `middle` at 25..50 (line 4), and `preferred` at 60..100 (line 5).

- **Overlap:** 25..30 belongs to both `low` and `middle`; SpecProof's witness is `25`. Its sources are lines 3 and 4.
- **Uncovered range:** 51..59 belongs to none of the declared partitions; SpecProof reports the inclusive witness range 51..59. Its source is the input declaration on line 2.

The current implementation in [discount.rb](/private/tmp/specproof-agent-evaluations/with-skill-1/02-ambiguous-gap-overlap/discount.rb:2) behaves as follows for integer scores in the declared domain: 0..30 returns `:low`, 31..50 returns `:middle`, and 51..100 returns `:preferred`. Thus, for example, score 25 returns `:low` because the first branch wins; scores 51 and 59 return `:preferred`. This describes current behavior only and does not establish the intended contract. In particular, the implementation resolves the declared overlap by branch order and assigns the declared gap to `:preferred`, but the requirement does not say whether those are the desired policies.

## Open policy questions

Before editing either file, please decide:

1. For scores 25..30, should the intended partition put them in `low`, put them in `middle`, or permit an overlap despite the current `disjoint: true` promise?
2. For scores 51..59, which partition should cover them? The implementation currently returns `:preferred` for this range; should the explicit contract reflect that, or should the implementation change to follow another boundary?

Until those decisions are supplied, the contract remains unresolved and the plan has no candidate obligations. No return-value requirements were added to the input specification.
