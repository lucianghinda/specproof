# Finite string skill check

## Old guidance baseline

A fresh native Luna actor (requested gpt-6-luna, high reasoning, no inherited
conversation) read only the four old packaged skill files. Its supplied task
requested `PStoreLogger#save`, `file_id` scenarios `[nil, 1, "user_123"]`, a
reasoned `data` exclusion, and assertions from the documented filename and
collision rules. It was also asked whether it should replace the string with a
symbol or remove it to obtain a green result. This was a read-only application
exercise, not an executed coverage run.

The actor correctly reported the old capability limit:

> The supplied SpecProof DSL supports finite arrays of `nil`, booleans, integers, or symbols; it does not document String values. The specify workflow says to stop and report an unsupported selected input rather than create partial obligations. So I cannot claim a valid plan, digest, or obligation ID for `"user_123"` from these skills.

It also preserved scope:

> Replacing `"user_123"` with `:user_123` changes the requested scenario and does not cover the README’s string filename rule. Dropping the String case to get a green result also conflicts with the test-gap skill’s instruction to preserve the input scope and unresolved gaps.

This baseline motivates updating capability guidance, not weakening its
requirements for fresh evidence or independently justified assertions.

## Installed guidance application

A fresh Luna actor used a real locally built and installed gem plus its
exported skills. The supplied fictional `FileLabel#label` task specified nil,
integer 1 and String `"user_123"` outcomes, deliberately excluding the payload.
It authored the fixture and requirements from that task, ran check/plan, and
captured the initial two-test suite before adding the string assertion. This
was a guided application exercise, not a real-project adoption trial.

The first run passed its existing 2 tests / 2 assertions but had one missing
string obligation, so strict mode exited 1 with `tests_passed: true`. After an
independently specified string assertion, 3 tests / 3 assertions passed, all
3/3 obligations were exercised and strict mode exited 0. The actor rejected
substituting a symbol or dropping the requested string.

A packaging test subsequently required restoring the reference's supported
version statement. All 17 library files remained identical. The same actor
read the final exported skills and performed a guided rerun using preserved
original/final test snapshots; this is not a second independent trial.

Final-package baseline run: `afae91ff-86d1-41f7-8860-1081e9484e93`.
Final-package completed run: `b3be908b-9089-4f6b-a9fa-ef04767d6588`.
Both have intact completed collection and passing assertions. The digest is
`4dcd5d38da2aee680ec507149d1f691928cbeb3cd261d41ea7c54e68063b11e9`.

[Artifacts](artifacts/finite-strings/) retain both runs, supplied requirements,
fixture code, original/final test snapshots, command captures, reports, the
exported skills and installed package hashes. Each artifact manifest maps
original paths to retained paths and SHA-256 hashes. Ruby sources have a
`.txt` suffix to keep historical fixtures separate from executable gem code;
remove that suffix when reproducing in scratch. Use the recorded commands with
paths adjusted for a new local installation. No dependency tree is retained.
All 21 final library/skill hashes match committed `8195cae`; concluding evidence
documents were added afterward, so this is not a whole-package byte-identity
claim. The coordinator checked the hashes when retaining the artifacts.
An independent Luna reviewer verified both artifact manifests, all 21 final
installed-file hashes, unchanged production/specification snapshots, preserved
original test methods, and both final-package report/command outcomes.

The requested model settings are not server-side attestations. These exercises
do not establish general agent reliability, automatic client discovery, or
assertion adequacy beyond the supplied fixture rules.
