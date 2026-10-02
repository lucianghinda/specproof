# Guided evaluation result

## Loaded assets

- `TASK.md` and `requirements.md` in this evaluation workspace.
- Selected RBS signature: `sig/project.rbs`, declaring `Feature#enabled?` with input `bool | String` and return type `bool` on line 2.
- Exported `.agents/skills/specproof-specify/SKILL.md` and `.agents/skills/specproof-specify/references/usage.md`.

The requirements provide no output behavior oracle. The RBS return type does not establish expected output values.

## Action and outcome

Ran the specified capture command for:

```text
specproof check --rbs sig/project.rbs --target 'Feature#enabled?' --format json
```

The recorder selected the installed SpecProof 0.1.0 executable using its configured isolated GEM_HOME. The command exited with status 2. The structured report contains this error:

```text
code: unsupported_rbs_type
message: unsupported RBS input type ::String: Feature#enabled? / input enabled
source: sig/project.rbs, line 2, kind rbs
```

SpecProof cannot represent the complete declared input because the selected target's `String` union arm is unsupported. The tool identifies the input as `enabled`; the limitation is at the imported RBS type, not a gap that can be repaired by narrowing the contract.

## Scope and stopping point

No partial union import, narrowing workaround, DSL declaration, signature/rule/skill change, or output assertion was made. Check produced an error, so its required clean-check prerequisite for `plan` was not met; no plan was run. There is no contract digest or candidate plan to report. Recorder evidence is in `logs/check.json`, and the structured check report is in `reports/check.json`.
