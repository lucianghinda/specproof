# Agent-skill evaluation, SpecProof 0.1.0

## Finding

In this small, rubric-scored benchmark, all 12 selected final-reference skill-guided attempts met their scenario rubrics. Five of the six selected no-skill baselines met theirs; the revised age-boundary baseline did not demonstrate the required failing regression assertion before changing the implementation. That baseline miss is retained as an experiment observation, not a blocker. The guided runs show that these particular tasks were completed with the skill instructions loaded. They do not establish a quantitative causal effect or a general success rate for agent skills.

## Evaluation setup

The retained run manifest records model `gpt-6-luna`, requested reasoning effort `high`, SpecProof `0.1.0`, schema 1, criterion `input-basics-v1`, Ruby `4.0.1`, and Codex CLI `0.160.0`. All six baselines and 11 of the 12 selected guided attempts used native collaboration agents with fresh forks (`fork_turns: none`) and requested high reasoning. The remaining guided attempt, case 01 attempt 2, used Codex CLI `0.160.0` with `--ephemeral --ignore-user-config`; the model used was Luna, but its reasoning effort was unpinned. The isolated gem environment was `GEM_HOME=/private/tmp/specproof-validation-gems`, `GEM_PATH=/private/tmp/specproof-validation-gems`, and `MT_NO_PLUGINS=1`, with Ruby at `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby` and the installed executable at `/private/tmp/specproof-validation-gems/bin/specproof`. The recorded command form was `env GEM_HOME=… GEM_PATH=… MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check|plan SPECIFICATION.rb [--format json]`, plus each fixture's existing Ruby test command where one existed. Minitest was the unmodified installed `5.27.0`.

The 11 native guided runs requested high reasoning. The Codex CLI run's high reasoning was not verified because the client default was unpinned. No randomized trials were run.

The benchmark contains six scenario rubrics under [`test/fixtures/agent_skills`](../../test/fixtures/agent_skills/README.md): domain partitions, ambiguous gap/overlap, age boundary, missing behavior oracle, stale coverage report, and pressure to narrow a contract. The original `baseline/03` and `baseline/04` fixtures were revised: the selected comparators are therefore `baseline-v2/03` and `baseline-v2/04`, which add the independent age requirement and explicitly agreed no-oracle input domain. The superseded baseline records remain archived and are not counted as extra trials.

| Scenario | Selected baseline | Guided attempt 1 | Guided attempt 2 |
| --- | --- | --- | --- |
| 01 — domain partitions | Pass | Pass | Pass (Codex CLI; reasoning unpinned) |
| 02 — ambiguous gap/overlap | Pass | Pass | Pass |
| 03 — age boundary | **Fail** — final suite passed, but no age-18 red run was demonstrated before the production edit | Pass — red age-18 assertion recorded before fix | Pass — red age-18 assertion recorded before fix |
| 04 — no expected-result oracle | Pass | Pass | Pass |
| 05 — stale coverage report | Pass | Pass | Pass |
| 06 — pressure to narrow contract | Pass | Pass | Pass |

Scoring follows each private fixture rubric, not the presence of a successful final command alone. In case 03, the v2 baseline's [`RESULT.md`](artifacts/baseline-v2/03-age-boundary/RESULT.md) reports a final passing suite but does not establish the rubric's required red-before-fix sequence. Both selected guided records do establish it. In case 05, accepted attempts treated the bundled incomplete report as untrusted and based current coverage claims on fresh runs. No accepted result was found to invent a requirement, lower an obligation denominator, or claim closure from stale evidence. For guided case 01 attempt 2, the final client message calls the lack of validation for out-of-domain inputs an “implementation mismatch.” The archived `RESULT.md` accurately describes enforcement as unresolved; the requirements constrain valid inputs and specify no behavior outside that domain. The source and result do not require rejection of invalid inputs or infer output behavior, so this wording did not change the rubric score. The per-run records and final workspace archives are in [`artifacts`](artifacts/manifest.json).

## Skill and client evidence

The two evaluated assets are `specproof-specify` and `specproof-test-gaps`. Their SHA-256 digests, also recorded in the manifest, are:

- `skills/specproof-specify/SKILL.md`: `feee53fcb41d8a6f3dc8ac11e0aab94be7e7e760a510ee0a6fad171cbd7f045c`
- `skills/specproof-specify/references/usage.md`: `97c3c89ade4bf6a211e596b903018fba78f0cf5aa383823743bdafbdbadcc943`
- `skills/specproof-test-gaps/SKILL.md`: `7442589ae052ac090b7ad1edd8e5c350abee1f18577da1657324b1e081a42e7a`
- `skills/specproof-test-gaps/references/usage.md`: `cdb33532404cddb42c0c93b0f6a77a8ef09eb7ca9e488ec364d550dbfa940a0d`

The `SKILL.md` bodies stayed unchanged; the two bundled usage references were updated, and these selected runs loaded the final reference hashes. I checked the listed hashes against the current packaged assets; they match. The final positive client trace is [`codex-release-client-events.jsonl`](artifacts/codex-release-client-events.jsonl): case 01 attempt 2 loaded `.agents/skills/specproof-specify/SKILL.md` and its usage reference, then executed SpecProof. A prior client startup in an untrusted temporary directory exited before the workflow; a fresh isolated workspace captured the retained run. Within that run, the first SpecProof executable call used ambient gem paths and failed with `LoadError`; retrying with explicit isolated gem paths succeeded. The earlier positive client trace remains in [`codex-client-events.jsonl`](artifacts/codex-client-events.jsonl). [`codex-unrelated-events.jsonl`](artifacts/codex-unrelated-events.jsonl) is a negative routing control: a formatting-only request changed a Ruby file without invoking SpecProof or creating a SpecProof artifact, and it did not load a skill.

## Limits and artifact accounting

The scored set is six selected baselines (four original fixtures plus the two v2 replacements) and 12 selected final-reference guided attempts. The prior 12 guided attempts remain archived under `pre-final-with-skill-1/` and `pre-final-with-skill-2/` and are not counted in this result. The retained `earlier/02` runs predate those attempts. `discarded/03` and `discarded/05` document skill-loading failures and are also excluded. `discovery-unrelated` is the separate negative control, not a seventh scenario.

The archives preserve final workspace files and result records, not pre-edit snapshots or complete native subagent transcripts. The final attempts ran with the same SpecProof core and skill assets from the evaluation task cut. The executable example runner and its documentation were added after those model attempts; their deterministic workflow tests are separate verification, not part of this benchmark. These results remain a small descriptive audit: task selection, fixture revisions, and the single skill-guided Codex CLI run limit direct baseline-versus-guided inference. No claim is made that guidance caused the observed difference or that it generalizes beyond these fixtures.
