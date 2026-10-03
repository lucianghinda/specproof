# Pairwise suggestions evidence

`pilot/` contains the All-in-Ruby clean-HEAD pilot, its original source and
tests, the separate added test, actual reports and command records. The
source checkout had pre-existing edits; manifests distinguish its working
files from the clean revision used in the pilot. The original project README
is stored verbatim in `pilot/README.source.json` under `content`.

`agent/` contains a fresh installed-skill actor's specification, runner,
requirement-backed assertion and actual execution evidence. The deliberately
faulty fixture stays unchanged. Its final failing assertion is expected and
is distinct from this gem's passing regression suite.

`verification/` records the Ruby/RBS matrix and coordinator checks.
`installed-sha256.json` identifies the final installed library and skills;
`manifest.json` hashes the retained evidence files. Earlier installed hashes
inside the actor evidence are historical; the `final-installed` manifest is
the one compared with current source.

Ruby snapshots use `.rb.txt` and preserve their historical bytes. Absolute
scratch paths and run IDs are retained as execution provenance, not as
portable installation instructions. The runnable repository examples are
the portable starting point.
