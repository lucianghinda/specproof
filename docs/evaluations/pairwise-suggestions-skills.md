# Pairwise suggestion skill application

## Old guidance baseline — coordinator notes

A Luna actor read only the four packaged skill files from main at `09a26e3`.
It was given three Boolean group inputs with an explicit `all_allowed` claim,
two missing pairs, and a separate rule that the output counts true inputs.
It correctly proposed the manual assignment `a=true, b=true, c=true` and an
expected result of `3` from that independent requirement.

The actor identified the command gap: the old plan reported pair obligations
without generating a complete assignment. It also treated incomplete or
unknown observations as insufficient evidence of missing pairs. These are
coordinator notes from the response; a separate transcript was not retained.

This was a read-only application exercise, not an executed coverage run. The
actor had previously reviewed unrelated finite-string evidence; it did not
read the suggestions implementation or new guidance. Its requested model was
gpt-6-luna with high reasoning; this is not a server-side attestation.

## Fresh installed-skill exercise

A fresh Luna actor read the exported skills from the built and installed gem,
then authored a declaration, runner, and separate added test from a small
fixture's written requirements. The original production file and four tests
were preserved. The actor supplied the excluded `context` argument itself.

The actual baseline passed four assertions and exercised 9/12 pairs. `suggest`
returned one all-true assignment covering the three missing pairs. The added
assertion expected `3` from the independent count-true-flags requirement and
received `2`, exposing the fixture's seeded bug. The augmented report exercised
12/12 pairs with `tests_passed: false`; subsequent suggestions were empty and
preserved the failed result. An altered incomplete report was rejected with
`incomplete_coverage_report` and exit 2. The actor rejected pressure to forbid
the all-true tuple because the requirements explicitly allow it.

The full workflow was rerun after final review fixes using the refreshed
installed gem. [Actor result](artifacts/pairwise-suggestions/agent/RESULT.md),
[commands and exits](artifacts/pairwise-suggestions/agent/evidence/runs.json),
[source hashes](artifacts/pairwise-suggestions/agent/evidence/hashes.json), and
[installed file hashes](artifacts/pairwise-suggestions/installed-sha256.json)
are retained. Historical Ruby files use `.rb.txt` so they do not join this
gem's tests or lint scope. This is one local application exercise, not a
general benchmark of agent reliability or model identity.
