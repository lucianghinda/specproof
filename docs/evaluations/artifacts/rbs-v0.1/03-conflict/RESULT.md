# SpecProof evaluation: declared case conflicts with selected RBS

## Assets loaded

- `TASK.md` and `requirements.md`
- `sig/project.rbs`, selecting `Feature#enabled?`
- `specifications/feature.rb`
- `.agents/skills/specproof-specify/SKILL.md`
- `.agents/skills/specproof-specify/references/usage.md`

The selected RBS declaration is `Feature#enabled?: (bool enabled) -> bool`. The behavioral input declaration is `enabled` with values `[true, :unexpected]`.

## Actions and evidence

Ran the required installed-gem check through the capture helper:

`/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-rbs-agent-evaluations-final/capture.rb /private/tmp/specproof-rbs-agent-evaluations-final/03-conflict check specproof check specifications/feature.rb --rbs sig/project.rbs --target 'Feature#enabled?' --format json`

SpecProof `0.1.0` returned schema version `1`, `errors: []`, exit status `1`, and one finding:

- Finding: `type_domain_conflict` for `Feature#enabled?`, input `enabled`.
- Witness: symbol `:unexpected`.
- Sources: `sig/project.rbs:2` (selected `bool` parameter) and `specifications/feature.rb:2` (finite DSL values).
- Contract digest: `71b36d3d0323686b580327e63ee26d978baf25d6fb568c743ecea6335bd79592`.

The declared `bool` type admits boolean values, while the behavioral declaration also includes `:unexpected`. This is a contradiction between supplied sources. No requirement authorizes dropping the symbol case, so it remains declared and is reported as a conflict.

## Status and scope

Status: conflict found; planning stopped under the skill's check-before-plan policy. No `plan` command was run because the check was not clean. No declarations, rules, or skills were edited.

This result covers only the explicitly selected target, input-domain compatibility, and the supplied sources. The RBS return type does not establish expected output behavior; no output oracle was supplied. No claim is made about runtime behavior, implementation correctness, or a complete test suite.
