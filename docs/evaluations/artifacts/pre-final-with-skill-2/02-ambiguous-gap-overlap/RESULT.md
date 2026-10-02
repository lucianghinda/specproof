# SpecProof skill evaluation

## Provenance

- Task: `TASK.md` in this evaluation workspace.
- Skill: `.agents/skills/specproof-specify/SKILL.md`
- Skill SHA-256: `feee53fcb41d8a6f3dc8ac11e0aab94be7e7e760a510ee0a6fad171cbd7f045c`
- Bundled usage reference: `.agents/skills/specproof-specify/references/usage.md`
- Command provenance: the exact installed Ruby/SpecProof invocation supplied for this evaluation, run from `/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-2` against the explicit input file `specifications/discount.rb`.

## Command and outcome

Command:

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/discount.rb --format json
```

Exit status: `1` (the check found semantic findings; report `errors` is empty).

Exact JSON output:

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"check","errors":[],"contract_digest":"9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1","findings":[{"code":"partition_gap","target":"Discount#rate","input":"score","witness":[{"kind":"integer","value":"51"},{"kind":"integer","value":"59"}],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-2/specifications/discount.rb","line":2}]},{"code":"partition_overlap","target":"Discount#rate","input":"score","witness":{"kind":"integer","value":"25"},"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-2/specifications/discount.rb","line":3},{"path":"/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-2/specifications/discount.rb","line":4}]}]}
```

The digest is `9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1`.

## Interpretation

The declared domain is inclusive `0..100`. The declared `:low` partition covers `0..30`, `:middle` covers `25..50`, and `:preferred` covers `60..100` (`specifications/discount.rb:2-5`). The overlap witness is `25`, which belongs to both `:low` and `:middle`. The uncovered range is `51..59`, with endpoint witnesses `51` and `59`; neither belongs to a declared partition.

The current implementation (`discount.rb:2-6`) returns `:low` for scores at or below 30, then `:middle` through 50, and `:preferred` above 50. Therefore it returns `:low` at 25 (the first matching condition wins) and `:preferred` throughout 51..59. Those implementation results do not decide whether the overlapping input contract or the omitted contract range should be changed.

The skill says to report findings without changing the requirement or implementation, and to run `plan` only after declared promises check clean. Since this check found both a gap and overlap, no `plan` command was run.

## Changes and uncertainty

No policy, implementation, or specification files were changed. The only file created is this `RESULT.md` report.

The intended policy remains undecided. Should `:low` or `:middle` own score 25, and should scores 51–59 be part of `:preferred` (or another intended partition)? No boundary edits should be made until those choices are supplied.

A `git status` check was attempted from this fixture directory and returned `fatal: not a git repository`; this evaluation fixture has no Git metadata. This does not affect the SpecProof result.
