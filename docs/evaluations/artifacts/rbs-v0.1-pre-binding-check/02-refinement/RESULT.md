# Refinement result

Loaded and followed `.agents/skills/specproof-specify/SKILL.md` and its `references/usage.md` in the supplied workspace. The selected RBS target is `Registration#eligible?` from `sig/project.rbs`.

Added only the missing age refinement in `registration.rb`: age is `0..120`, with exhaustive, disjoint `minor` (`0...18`) and `adult` (`18..120`) partitions. Consent remains RBS-supplied (`bool?`); no consent declaration was duplicated in the DSL.

Verified with SpecProof 0.1.0. The `check` report has no errors or findings and contract digest `03501b28c964e6614a246f1520ecdb367e9d94f021ec3e7ea7b1dfc2f52dad3e`. The subsequent `input-basics-v1` plan has the same digest.

The plan proposes age candidates `0`, `1`, `17`, `18`, `119`, and `120`, covering the domain endpoints, endpoint neighbors, and partition boundaries. It also gets consent candidates `nil`, `false`, and `true` directly from the RBS signature. DSL provenance is `registration.rb:4` for the age range, `registration.rb:5` for `minor`, and `registration.rb:6` for `adult`; RBS provenance is `sig/project.rbs:2` for the selected signature and consent candidates.

Limitations: these are boundary candidates, not a complete or proven test suite. The isolated workspace supplies the independent behavior rule and signature but no implementation or tests, so this result checks the input contract and does not verify the method’s actual behavior or expected outputs. All CLI commands, including version, check, and plan, were run through the supplied capture helper; their command logs and JSON reports are in `logs/` and `reports/`.
