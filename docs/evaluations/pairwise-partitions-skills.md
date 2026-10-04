# Partition pairwise skill exercise

Two fresh Luna agents used separate fixture copies and the installed feature
gem. The [task and constraints](artifacts/pairwise-partitions/PROMPTS.md) are
retained with their reports. This is a post-implementation guidance comparison,
not a broad agent benchmark or a test-first skills claim.

With skills from `21959ba`, the baseline agent selected `pairwise-finite-v1`.
The check succeeded, but planning rejected the age range with
`finite_combinations_required`. The agent preserved the contract and reported
the limitation instead of inventing flags or substituting boundary coverage.
Its 3/4 category count was a manual interpretation, not a coverage measurement.
See the [baseline result](artifacts/pairwise-partitions/baseline/RESULT.md).

With the updated packaged skills, the guided agent selected
`pairwise-partitions-v1`, measured 3/4 pairs, obtained the concrete suggestion
`age: 0, country: "de"`, and added an assertion citing the independent under-18
requirement. The corrected final run passed 2 tests and 4 assertions, measured
4/4 pairs, and produced no further suggestions. Changing a category bound in a
copy of the initial report produced `coverage_contract_mismatch`. See the
[guided result](artifacts/pairwise-partitions/guided/RESULT.md).

The fixture contained a dormant reference assertion. The coordinator corrected
the runner's initial flag collision so only the agent-added assertion closed
the measured gap. This limits claims of unaided assertion discovery. The
original fixture specification, production method, requirements, and tests
remained byte-identical. The evidence demonstrates command selection, report
interpretation, oracle provenance, and rejection of altered evidence; it does
not demonstrate behavioral equivalence or comprehensive correctness.

The installed gem's 26 library and skill files were checked against the final
worktree. The [installed file hashes](artifacts/pairwise-partitions/installed-manifest.json)
and [artifact manifest](artifacts/pairwise-partitions/manifest.json) retain the
comparison evidence. Packaged skill export recognized all four supplied
guided skill/reference files as unchanged.
