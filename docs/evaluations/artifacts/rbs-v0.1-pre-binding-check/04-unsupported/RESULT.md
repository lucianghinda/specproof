# Evaluation result

The selected target could not be checked or planned as a whole. SpecProof 0.1.0 reports the `String` arm of the explicitly selected RBS union as unsupported. The supplied type and requirements remain unchanged; no DSL narrowing, partial obligation set, or plan was created.

## Supplied context and assets loaded

- Read `TASK.md`: the target is `Feature#enabled?`; the task explicitly prohibits narrowing the selected input type.
- Read `requirements.md`: this is input-domain checking/planning only, and no output behavior oracle is supplied.
- Read `sig/project.rbs`: line 2 declares `Feature#enabled?: (bool | String enabled) -> bool`.
- Explicitly loaded `.agents/skills/specproof-specify/SKILL.md` and `.agents/skills/specproof-specify/references/usage.md`.
- The fixture has no files under `lib/`, `test/`, or `specifications/`, so it supplies no Ruby method implementation or tests to inspect.

## Check evidence

Ran the prescribed capture helper from this fixture directory:

```text
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-rbs-agent-evaluations/capture.rb /private/tmp/specproof-rbs-agent-evaluations/04-unsupported check specproof check --rbs sig/project.rbs --target 'Feature#enabled?' --format json
```

The helper selected SpecProof 0.1.0 and recorded the underlying command and complete result in `logs/check.json`; the structured report is `reports/check.json`. The check exited with status 2 and returned:

```text
code: unsupported_rbs_type
message: unsupported RBS input type ::String: Feature#enabled? / input enabled
source: /private/tmp/specproof-rbs-agent-evaluations/04-unsupported/sig/project.rbs:2 (kind: rbs)
```

The error prevents producing a clean check or contract digest. Per the loaded skill, unsupported union arms are atomic failures: the `bool` arm cannot be planned on its own, and no replacement finite domain or behavioral refinement is justified by the supplied requirements. A plan command was therefore not run. No boundary candidates are reported.

## Limitation

For this selected target and this supplied signature, SpecProof 0.1.0 cannot import the full `(bool | String)` input because `::String` is unsupported. This finding is limited to the observed type and tool version; it does not establish general RBS support or lack of support beyond this case. The task would need a tool that can handle this union or revised authorized requirements/type before a whole-domain plan can be made.
