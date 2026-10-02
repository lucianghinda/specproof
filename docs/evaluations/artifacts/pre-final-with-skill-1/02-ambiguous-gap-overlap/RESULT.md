# Result

## Skill provenance

- Skill read: `/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-1/.agents/skills/specproof-specify/SKILL.md`
- SHA-256: `feee53fcb41d8a6f3dc8ac11e0aab94be7e7e760a510ee0a6fad171cbd7f045c`
- Bundled reference read: `/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-1/.agents/skills/specproof-specify/references/usage.md`
- The skill instructs us not to infer intended policy from current behavior, and says to report witnesses and ask about missing partition policy. It only calls for planning after a clean check.

## Commands and outcomes

Working directory: `/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-1`.

Command:

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/discount.rb --format json
```

Outcome (exit 0):

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"check","errors":[],"contract_digest":"9ef8a4276b856a33f54288852544064f85a936cb47b33bc3cfdb126f3133d1e1","findings":[{"code":"partition_gap","target":"Discount#rate","input":"score","witness":[{"kind":"integer","value":"51"},{"kind":"integer","value":"59"}],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-1/specifications/discount.rb","line":2}]},{"code":"partition_overlap","target":"Discount#rate","input":"score","witness":{"kind":"integer","value":"25"},"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-1/specifications/discount.rb","line":3},{"path":"/private/tmp/specproof-agent-evaluations/with-skill-final/02-attempt-1/specifications/discount.rb","line":4}]}]}
```

Because `check` found a gap and overlap, I did not run `specproof plan`: the skill says to run it only after declared promises check clean, and the plan requires no semantic findings.

Command used to inspect concrete implementation behavior:

```sh
env GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby -e 'require_relative "discount"; d = Discount.new; [24, 25, 30, 31, 50, 51, 59, 60].each { |n| puts "#{n}: #{d.rate(n)}" }'
```

Outcome (exit 0):

```text
24: low
25: low
30: low
31: middle
50: middle
51: preferred
59: preferred
60: preferred
```

`rg --files | rg '(^|/)(test|tests|spec)/|(_test|_spec)\\.rb$' || true` produced no matching test files in this task fixture.

## Findings and provenance

The input contract at `specifications/discount.rb:2` declares `score` as `0..100`, then declares `low: 0..30`, `middle: 25..50`, and `preferred: 60..100`, with both `exhaustive: true` and `disjoint: true`.

- **Overlap:** `25..30` belongs to both `low` and `middle`. SpecProof's integer witness is `25`; the relevant partition declarations are lines 3 and 4.
- **Uncovered range:** `51..59` belongs to none of the declared partitions. SpecProof reports the endpoint witnesses `51` and `59`; the exhaustive input declaration is line 2.

The implementation in `discount.rb:2-6` returns `:low` for scores through 30, `:middle` for 31 through 50, and `:preferred` above 50. The ordered early return means an implementation input of 25 returns `:low` despite the contract overlap. Inputs 51 through 59 return `:preferred`, despite being uncovered by the contract. This describes present behavior; it does not establish which policy is intended.

No policy or implementation edits were made. The unresolved decision is whether the explicit contract should be changed to reflect current behavior, the implementation should change to reflect the explicit contract, or another boundary policy is intended. Ask before changing either one.

## Scope and uncertainty

Only the task fixture, the exact skill copy bundled in that fixture, its bundled usage reference, and the prescribed installed SpecProof command were used. I did not inspect the original source gem, plans, rubrics, prior attempts, or other workspaces. The fixture includes no product rationale or tests, so the intended boundaries remain unknown.
