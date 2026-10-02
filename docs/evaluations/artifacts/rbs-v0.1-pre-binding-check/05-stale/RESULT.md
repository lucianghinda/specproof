# Fresh stale-report evaluation

## Assets loaded

- `TASK.md`, `requirements.md`, `supplied-context.json`, and `reports/baseline.json`
- Current implementation `lib/registration.rb`, test `test/registration_test.rb`, DSL `specifications/registration.rb`, RBS `sig/project.rbs`, and suite entrypoint `run.rb`
- Exported skill `.agents/skills/specproof-test-gaps/SKILL.md` and `references/usage.md`

The target and parameters agree: `Registration#eligible?` accepts keyword `age` and optional keyword `consent`. The independent rule says eligibility requires `age >= 18` and `consent == true`; ages are in `0..120`, and nil/false consent deny eligibility.

## Actions

- Ran fresh offline `check` and `plan` with `specifications/registration.rb`, explicit `--rbs sig/project.rbs`, and `--target 'Registration#eligible?'` using the supplied capture helper and Ruby 4.0.1.
- Ran `REPORT_NAME=fresh.json ... capture.rb <workspace> fresh-run ruby run.rb` in a fresh process. The entrypoint loads `test/registration_test.rb` and writes `reports/fresh.json`.
- Compared the implementation SHA-256 with the supplied source hashes. It is `49169a649356269f4fd8bd0eb373002b136de78eac1d58e06c4e926b51973ccb`, matching `current_source_hash` and differing from the baseline hash `ecea83d2754e6fbd1e5ac3944f672c173af69b623503da99370688b987180e18`.
- Did not modify implementation, tests, declarations, or skills.

## Evidence

- Fresh `check`: exit 0, SpecProof `0.1.0`, no errors/findings; digest `03501b28c964e6614a246f1520ecdb367e9d94f021ec3e7ea7b1dfc2f52dad3e`.
- Fresh `plan`: exit 0, same digest, 9 obligations. Its IDs match the baseline's 9 IDs. This confirms the input contract is unchanged; it does not fingerprint the implementation.
- Fresh runtime report `reports/fresh.json`: run ID `10a9b1ba-7010-4609-958d-335cec024cf6`, matching the run summary in `logs/fresh-run.json`; same current plan digest and all 9 obligation IDs.
- Report scope has target `Registration#eligible?`; declaration sources are this workspace's `specifications/registration.rb` and `sig/project.rbs`, with target `Registration#eligible?`. Arguments are empty, filters/exclusions are null. `run.rb` requires `test/registration_test.rb`.
- Runtime report has `completion: completed`, `integrity: true`, `tests_passed: false`, 5/9 obligations exercised, and 4 unobserved: `age=119`, `age=120`, `consent=nil`, `consent=false`. `unknown_count` is 0, errors/incomplete reasons are empty, and outside-domain is empty.
- The fresh suite exits 1: 1 test, 4 assertions, 1 failure at `test/registration_test.rb:7`, “Expected false to be truthy.” The first adult example is age 18 with consent true. Current implementation returns false because it checks `age > 18`; the independent rule requires true at age 18. The failure stops the remaining examples, explaining the four unobserved obligations.

## Current status

The prior report does **not** establish current coverage: it predates the implementation edit, and the implementation source hash changed. The fresh report is current evidence, but it does **not** establish a fully covered passing suite. It exposes an age-18 behavior failure and leaves four obligations unobserved. The plan/check remain clean because this is an implementation behavior issue, not an invalid input declaration.

## Limitations

SpecProof observes target calls, not assertion meaning or correctness. The expected age-18 result comes from the independently supplied behavior rule, not from the RBS return type or coverage hit. Because this evaluation explicitly forbids changing implementation/tests, no repair or post-fix passing report was attempted. Runtime report scope cannot attest loaded test files by itself; the loaded file was confirmed by reading `run.rb`.
