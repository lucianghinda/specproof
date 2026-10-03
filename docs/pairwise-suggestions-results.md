# Pairwise suggestion results

SpecProof can turn a completed pairwise coverage report into deterministic
allowed assignments for its missing pairs. The Ruby API is
`SpecProof.suggest(specifications, report: parsed_json)`; the CLI is
`specproof suggest SPEC.rb --report coverage.json [--rbs FILE --target TARGET]
--format json`. Suggestions always use `pairwise-finite-v1` and
`greedy-pairwise-v1`.

Before selecting assignments, SpecProof replans the supplied declarations and
checks the report's schema, kind, criterion, digest, exact typed obligation
denominator, declared scope, counters, statuses, and projections. The source
run must be completed and intact, with no errors or unknown observations.
Either Boolean `tests_passed` value is accepted and retained, and filtered
reports remain limited to their recorded scope. The result preserves the
source run ID and scope so callers can review what evidence it used.

Each suggestion is a full assignment for a declared combination group. Its
`covers` list names only newly covered missing pair IDs; the union of those
lists is the missing set. `unassigned_inputs` lists analyzed method parameters
outside the group and explicitly excluded parameters. The caller must supply
those values, and all analyzed values must still be valid for runtime evidence.
Suggestions are not executed and provide no expected outputs. They are not a
minimum-size covering set: the deterministic greedy strategy chooses the
largest current gain and breaks ties by canonical typed assignment order.

Use a separate requirement as the oracle for every assertion. A contract
digest covers normalized input declarations, not implementation or test bytes,
so rerun the intended suite after code or test changes. Suggestion work is
bounded to 10,000 cumulative full assignments, 10,000 cumulative possible pair
rows, 1,000,000 candidate-to-missing-pair memberships, and a 32 MiB input
report. Oversized work is rejected without sampling, truncation, or partial
results.

## AllInRuby pilot

The real-project pilot used `AllInRuby::Installer#install` in a scratch copy of
the project. Its pairwise group contains the finite `scope`, `dry_run`, and
`backup` inputs. `agents` is explicitly excluded because it is a collection
parameter that each test must supply separately. The project README documents
the individual scope and option behavior used to justify the group; no
implementation-derived restriction was added.

The captured baseline passed its existing suite and observed 9 of 12 pair
obligations. The three missing pairs all fit in the allowed assignment
`scope: "global", dry_run: true, backup: false`. SpecProof returned that one
candidate and listed `agents` as unassigned. The follow-up test in the scratch
copy checks the documented dry-run preview, absence of a backup, and unchanged
file contents. The original 32 tests and 104 assertions passed; adding one test
produced 33 passing tests and 114 assertions, with 12/12 pairs exercised. The
fresh report then produced no suggestions. This is a coverage improvement,
not a discovered production defect.

The copy came from clean HEAD `bbe9921470cbf80ae01ae4fbb2de50a62187ba9e`;
the source checkout's pre-existing edits were preserved. The group is an
explicit pilot declaration based on documented independent options, not an
inferred business rule. [Retained pilot evidence](evaluations/artifacts/pairwise-suggestions/pilot/pilot-notes.md)
includes requirement citations, original tests, the added assertion, commands,
reports, and source hashes.

## Installed-skill exercise

The installed `specproof-test-gaps` exercise used a fresh Luna actor. Its baseline
and pairwise plan describe `ToggleSummary#count` with three Boolean group
inputs and caller-supplied `context`. The current suggestion output proposes
`a: true, b: true, c: true` for the three missing pairs and lists `context` in
`unassigned_inputs`. The added assertion expects three from the separate
requirement to count true flags. It exposes the seeded defect (actual result
two): coverage reaches 12/12 while `tests_passed` stays false. Suggestion output
preserves that failed result and reports zero missing pairs. An altered
incomplete report is rejected with exit 2. The actor also refused to hide the
defect by forbidding a combination the requirements explicitly allow.

See the [skill evaluation](evaluations/pairwise-suggestions-skills.md) for the
old-guidance comparison and executable evidence.

## Review

Independent Luna specification and quality reviews checked the evidence gate,
deterministic selection, and CLI. Review moved cumulative checks ahead of
enumeration and replaced quadratic preflight pair counting with an incremental
sum that stops at the limit. Full assignments are cached only when requested,
so ordinary coverage does not retain them. Typed report encodings are validated
explicitly; no dependency or lint threshold was added.

## Verification

| Check | Status |
| --- | --- |
| Core suite on Ruby 3.3.6, 3.4.7, 4.0.1 | 250 tests / 1,297 assertions per runtime |
| Optional RBS suite on those runtimes | 47 tests / 436 assertions per runtime |
| RBS signature validation on those runtimes | Passed |
| Default locked development bundle, `rake` | Passed; 126 files linted without offenses |
| `bin/check` | Syntax, 2 packaging tests / 76 assertions, and gem build passed |
| AllInRuby installed-gem pilot | 9/12 to 12/12, assertions passing |
| Installed-skill exercise | 9/12 to 12/12, requirements-backed failure preserved |

Existing method-redefinition fixture warnings and the missing-homepage gemspec
warning remain. [Matrix evidence](evaluations/artifacts/pairwise-suggestions/verification/commands.json)
records exact commands and environments; the installed library and skill hashes
match the reviewed source.

For a runnable, self-contained demonstration of the API and report boundaries,
see the [pairwise suggestions example](../examples/pairwise_suggestions/README.md).
