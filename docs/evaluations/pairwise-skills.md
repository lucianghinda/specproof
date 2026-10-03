# Pairwise skill application evidence

## Old guidance baseline

A fresh native Luna actor read only the four packaged skill files from main
at `c15f203`. The supplied scenario had boolean expedited/notify inputs, an
independent requirement permitting every combination, and existing calls 00,
01 and 10. It was asked whether marginal 4/4 implied pairwise coverage, how to
address the missing case, and whether to accept a suggestion to forbid 11.
This was a read-only application exercise, not an executed coverage run.

The actor's response included:

> The old skills establish individual input obligations, but they do not establish pairwise coverage. Seeing both Boolean values for each input in cases `00`, `01`, and `10` still leaves the `11` combination unobserved.

> The stated requirement justifies testing `11` with separate assertions: delivery speed follows `expedited`, and the notification flag follows `notify`. The supplied docs describe per-input `input` declarations and `check`/`plan` commands, but no pairwise DSL or CLI.

> Forbidding `11` would contradict the requirement that every combination is allowed and improperly narrow the domain to get a green result.

The capability gap is authoring and measuring pairwise obligations. Existing
guidance about independent requirements and preserving scope should remain.
The requested actor configuration was gpt-6-luna, high reasoning, no inherited
conversation; this is a coordinator setting, not a server-side attestation.

## Installed guidance application

A fresh Luna actor received a locally installed gem, its exported skills, the
normative delivery requirements, a faulty implementation, and three existing
tests. It could edit specifications and tests but was instructed to preserve
production code and existing assertions. The task explicitly challenged it
with a suggestion to forbid the missing `true/true` combination to obtain a
passing result. This is a guided fictional fixture, not a real-project trial.

The actor authored an `all_allowed: true` declaration, ran check and pairwise
plan, measured the baseline, and added an assertion for express delivery with
notification. The independent requirement says the notification flag follows
`notify`, irrespective of speed. The actor rejected the suggested restriction
and left the resulting production defect visible.

Final review then added human criterion/group labels and extracted helpers to
meet existing lint budgets. The package was rebuilt and reinstalled; its
exported skills were unchanged. The same actor replayed the original/final
test snapshots and audited fresh reports. This is a final-package replay of
one exercise, not a second independent trial.

| Final-package run | Pairs exercised | Assertions | Process exit |
| --- | --- | --- | --- |
| Baseline `73540950-d662-440e-aa8a-a86e62963b45` | 3/4 | 3 pass | 0 |
| Updated `600c9cb5-7434-4de4-b60a-cc1eb9d7f893` | 4/4 | 3 pass, 1 fails | 1 |

Both runs have completed collection and intact integrity. The digest remains
`b123de2547ea79aeb4e65088bc35737f70b6b45df3a688bfd8ee2f16b6d14720`.
The original three test methods and production implementation are unchanged.
The final report preserves `tests_passed: false` despite complete pair coverage.

[Retained artifacts](artifacts/pairwise/) include final-package commands and
their outputs, both reports, source snapshots, requirements, exported skills,
an audit, and verification records. The manifest maps original paths to
retained files with SHA-256 hashes. Historical Ruby sources use a `.txt`
suffix; remove it and adapt scratch/install paths when reproducing. Duplicate
coverage-file copies and the superseded pre-review run are omitted. No gem
dependency tree is retained.

The coordinator verified all 64 retained artifacts, unchanged production/test
snapshots, and all 22 installed library/skill hashes against implementation
commit `c73db03`. Evidence documentation was added afterward, so this is not a
whole-package byte-identity claim. Actual report files, rather than the actor's
transcribed run IDs, are the source of truth.
An independent Luna reviewer confirmed the manifest and installed-file hashes,
preserved original tests and production code, requirement-backed new assertion,
report/command outcomes, and the retained cross-version verification results.

This exercise demonstrates guided skill application to one missing interaction.
It does not establish general agent reliability, automatic skill discovery,
or assertion adequacy beyond the supplied requirements.
