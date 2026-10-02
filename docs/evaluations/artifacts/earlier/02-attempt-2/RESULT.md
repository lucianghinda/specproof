# SpecProof evaluation

## Task result

Ran SpecProof against `specifications/discount.rb` and inspected the current implementation in `discount.rb`. No policy edits were made. The contract digest is `9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1`.

The explicit input domain is `score: 0..100`, declared exhaustive and disjoint at `specifications/discount.rb:2`. Its partitions are `low: 0..30` (`:3`), `middle: 25..50` (`:4`), and `preferred: 60..100` (`:5`).

SpecProof reports:

- `partition_overlap`, witness `25`, between `low` and `middle` (`specifications/discount.rb:3-4`). The inclusive ranges overlap at every integer from 25 through 30.
- `partition_gap`, witness range `51..59` (`specifications/discount.rb:2`). No declared partition covers those scores.

The implementation in `discount.rb:3-6` currently returns `:low` for scores at or below 30, `:middle` for scores above 30 through 50, and `:preferred` above 50. Within the declared domain, its effective regions are `0..30`, `31..50`, and `51..100`. Thus the implementation has no gap or overlap, but its middle region differs from the declared `25..50`, and its preferred region starts at 51 rather than 60. This comparison describes current behavior; it does not establish the intended policy.

The `plan` command returned the same findings and digest, with criterion `input-basics-v1` and an empty `obligations` array. It supplied no candidate values. Because the declared exhaustive/disjoint promises fail, the plan is not a clean boundary-candidate plan.

## Commands and results

Both commands used the requested Ruby and environment:

```text
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/discount.rb --format json
```

Result: exit success; `errors: []`; findings `partition_gap` with witnesses 51 and 59, and `partition_overlap` with witness 25; digest as above.

```text
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/discount.rb --format json
```

Result: exit success; `errors: []`; criterion `input-basics-v1`; `obligations: []`; same two findings and digest; no candidate values. `git status` could not be used because this fixture directory is not a Git repository.

## Skill and file record

- Skill read: `/private/tmp/specproof-agent-evaluations/with-skill-2/02-ambiguous-gap-overlap/.agents/skills/specproof-specify/SKILL.md`
- Skill SHA-256: `feee53fcb41d8a6f3dc8ac11e0aab94be7e7e760a510ee0a6fad171cbd7f045c`
- Changed files: `RESULT.md` only.
- Uncertainty: requirements do not decide whether to correct the declared partitions or change implementation boundaries, nor what intended boundary values should be.

Which policy should govern scores 25–30 and 51–59, and what exact boundaries should apply? Please direct whether the specification or implementation should change before either is edited.
