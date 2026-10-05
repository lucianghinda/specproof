# Readable partition options

Replace documented `exhaustive` / `disjoint` DSL terminology with the approved
`allow_gaps` / `allow_overlaps` pair. Preserve behavior while making each rule
read directly as a permission.

- `allow_gaps: false` requires every domain value to belong to at least one partition.
- `allow_overlaps: false` requires every domain value to belong to at most one partition.
- Both default to true, preserving today's permissive behavior when options are omitted.
- Both accept only true or false. Requiring a partition policy still requires a nonempty partition family.
- Retain old spellings as compatibility aliases with inverted booleans. Reject both spellings of the same policy in one declaration, even when consistent; mixing different policy spellings is valid.
- Keep normalized IR fields, contract digest encoding and obligation identities stable. Equivalent old/new declarations must accept the same coverage evidence.
- Update current diagnostics, examples, guides and agent skills. Preserve historical plans and evaluation artifacts as records of their original runs.

Implementation: add failing option/semantic/compatibility tests; normalize in the loader; update diagnostics and active fixtures; update documentation; review and run core, optional RBS, signatures, lint and package checks. No dependencies or constrained-pair feature work.

## Verification and review

The Luna implementer observed failing tests for unsupported new options before
adding loader normalization. An independent Luna review approved the behavior
and documentation. Its guidance-driven migration exercise changed
`exhaustive: true, disjoint: false` to
`allow_gaps: false, allow_overlaps: true` for overlapping partitions `0..60`
and `40..100` in domain `0..100`. Both checks had no findings; the digest and
all six scalar obligation IDs matched. Scratch fixtures were removed.

On Ruby 4.0.1, the complete core suite passed with 292 tests / 1,518 assertions,
and the optional RBS suite passed with 54 tests / 499 assertions. Signature
validation and all 140 lint files passed. Syntax, package, and skill-asset checks
passed (2 tests / 76 assertions). The updated runnable partition example passed
2 tests / 4 assertions and exercised all four category pairs. No dependencies,
IR fields, digest encoding, or report schema changed. Ruby 3.3 and 3.4 were not
rerun for this spelling change.
