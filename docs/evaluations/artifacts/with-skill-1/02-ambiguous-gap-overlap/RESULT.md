# SpecProof evaluation

## Findings

The declared input domain is `score: 0..100`, and the specification promises
that its partitions are exhaustive and disjoint ([specifications/discount.rb](/private/tmp/specproof-agent-evaluations/release-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb:2)).
SpecProof 0.1.0 reports no errors and two semantic findings:

- `partition_overlap`: witness `25`, included by both `low` (`0..30`) and
  `middle` (`25..50`), declared at lines 3 and 4.
- `partition_gap`: witness interval `51..59`, included by none of the declared
  partitions. `middle` ends at 50 and `preferred` starts at 60.

The current method has ordered conditions ([discount.rb](/private/tmp/specproof-agent-evaluations/release-skill-1/02-ambiguous-gap-overlap/discount.rb:2)):
scores through 30 return `:low`, scores 31 through 50 return `:middle`, and
scores 51 through 100 return `:preferred` within the declared domain. Thus for
the overlap witness 25, the method returns `:low` because that condition comes
first. For the gap witnesses 51 through 59, it returns `:preferred`. This
describes the current implementation only; it does not establish the intended
partition policy.

Which policy should apply to scores 25 through 30, and should scores 51
through 59 belong to `middle`, `preferred`, or another partition? Please decide
those boundaries before either the specification or implementation is edited.

No plan was generated: the skill/reference require a semantically clean check
before planning, and this check reports both a gap and overlap. No Ruby test
files were present in the assigned workspace, so no test command was run.

## Provenance

- Skill: `/private/tmp/specproof-agent-evaluations/release-skill-1/02-ambiguous-gap-overlap/.agents/skills/specproof-specify/SKILL.md`
  - SHA-256: `feee53fcb41d8a6f3dc8ac11e0aab94be7e7e760a510ee0a6fad171cbd7f045c`
- Referenced usage: `/private/tmp/specproof-agent-evaluations/release-skill-1/02-ambiguous-gap-overlap/.agents/skills/specproof-specify/references/usage.md`
  - SHA-256: `97c3c89ade4bf6a211e596b903018fba78f0cf5aa383823743bdafbdbadcc943`
- CLI version output: `SpecProof 0.1.0`
- Check contract digest: `9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1`
- Check report: `schema_version: 1`, `specproof_version: 0.1.0`, `errors: []`,
  findings `partition_gap` (`51..59`) and `partition_overlap` (`25`).
- Changed files: `RESULT.md` only. No source/specification edits.
- Uncertainty: intended ownership of the overlap and uncovered interval is
  undecided by the supplied prompt and README.

## Commands run

All CLI commands ran from
`/private/tmp/specproof-agent-evaluations/release-skill-1/02-ambiguous-gap-overlap`
with the assigned Ruby/gem environment.

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --version
```

Result:

```text
SpecProof 0.1.0
```

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/discount.rb --format json
```

Result:

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"check","errors":[],"contract_digest":"9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1","findings":[{"code":"partition_gap","target":"Discount#rate","input":"score","witness":[{"kind":"integer","value":"51"},{"kind":"integer","value":"59"}],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":2}]},{"code":"partition_overlap","target":"Discount#rate","input":"score","witness":{"kind":"integer","value":"25"},"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":3},{"path":"/private/tmp/specproof-agent-evaluations/release-skill-1/02-ambiguous-gap-overlap/specifications/discount.rb","line":4}]}]}
```
