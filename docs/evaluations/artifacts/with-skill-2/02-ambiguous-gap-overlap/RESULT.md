# Evaluation result

## Inputs and provenance

- Task: `TASK.md` in this workspace.
- Specification: `specifications/discount.rb`, targeting `Discount#rate`.
- Implementation inspected: `discount.rb`.
- Local workflow instructions: `/private/tmp/specproof-agent-evaluations/release-skill-2/02-ambiguous-gap-overlap/.agents/skills/specproof-specify/SKILL.md`
  - SHA-256: `feee53fcb41d8a6f3dc8ac11e0aab94be7e7e760a510ee0a6fad171cbd7f045c`
- Referenced command/report documentation: `/private/tmp/specproof-agent-evaluations/release-skill-2/02-ambiguous-gap-overlap/.agents/skills/specproof-specify/references/usage.md`
  - SHA-256: `97c3c89ade4bf6a211e596b903018fba78f0cf5aa383823743bdafbdbadcc943`
- CLI provenance: Ruby 4.0.1 at `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby`; SpecProof 0.1.0 loaded from `/private/tmp/specproof-validation-gems`, with `MT_NO_PLUGINS=1`.
- The workspace contains no test files and is not a Git repository.

## Commands and results

Version command:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --version
```

Output: `SpecProof 0.1.0`.

Check command:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/discount.rb --format json
```

Output:

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"check","errors":[],"contract_digest":"9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1","findings":[{"code":"partition_gap","target":"Discount#rate","input":"score","witness":[{"kind":"integer","value":"51"},{"kind":"integer","value":"59"}],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/02-ambiguous-gap-overlap/specifications/discount.rb","line":2}]},{"code":"partition_overlap","target":"Discount#rate","input":"score","witness":{"kind":"integer","value":"25"},"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/02-ambiguous-gap-overlap/specifications/discount.rb","line":3},{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/02-ambiguous-gap-overlap/specifications/discount.rb","line":4}]}]}
```

The report has no errors and has two semantic findings. Following the skill's workflow, `plan` was not run because planning requires a specification with no semantic findings.

## Findings and implementation comparison

The declared domain is integer scores 0 through 100, marked exhaustive and disjoint at `specifications/discount.rb:2`.

- **Overlap:** score 25 is in both declared `:low` (0..30, line 3) and `:middle` (25..50, line 4). The overlapping interval is 25..30.
- **Gap:** declared partitions leave 51..59 uncovered. SpecProof reports endpoint witnesses 51 and 59; the intervening integer scores are uncovered as well.
- **Implementation:** `discount.rb:3-6` returns `:low` for scores through 30, `:middle` for 31..50, and `:preferred` for 51 and above. Thus the implementation resolves 25..30 by first-match behavior as `:low`, and assigns the contract's uncovered 51..59 scores to `:preferred`. This is evidence of current behavior, not evidence that either policy is intended.

## Changes and unresolved decision

Only this `RESULT.md` was added. Neither the specification nor the Ruby implementation was edited.

The intended ownership of scores 25..30 and the intended treatment of scores 51..59 remain undecided. Please specify the desired partition boundaries (or intended handling) for both ranges before either policy is changed. No complete test suite or boundary plan is claimed.
