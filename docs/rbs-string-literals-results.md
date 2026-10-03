# RBS string-literal inputs

RBS 4.2.0 string literals now supply exact finite input domains to the existing
checker, planner, Minitest collector and suggestion command. A combinations-only
DSL declaration can use those imported values without repeating them. Optional
literal types, supported mixed unions, String/Symbol distinctions, source
provenance and DSL subset refinements retain the existing domain semantics.

The implementation reuses `Domains.supported_string?` and the existing immutable
type constraints. It adds no dependency, criterion or report schema. Reading
RBS files explicitly as UTF-8 matches RBS's own environment loader and prevents
locale-dependent interpretation of Unicode literals. Unrestricted `String`,
aliases, collections and other unsupported selected union members remain
rejected. Invalid UTF-8 files return `rbs_parse_error` with their path. Return
types remain outside analysis.

## Demonstrated workflow

The [DeliveryOptions example](../examples/rbs_string_literals/README.md) imports
`country: ("ro" | "de")` and `expedited: bool` from its signature. Three passing
calls exercise 3/4 pairs. The suggestion identifies `country="de",
expedited=true`; a separate assertion justified by the written delivery rule
produces a fresh 4/4 report. This demonstrates a coverage improvement without
claiming that full pair coverage proves behavior.

## Agent guidance

A Luna baseline actor read the previous main-branch skills at `53b621d` and
correctly reported that the literal-union workflow was unsupported. This is
a coordinator-retained summary, not a benchmark or model attestation.

A fresh Luna actor used the built gem's exported skills and the example's
independent requirement to run check, plan, coverage and suggestions. Its
baseline had one missing pair; the completed run had none. Separate unrestricted
`String` and literal-plus-`Object` probes failed atomically. The coordinator
replayed the workflow against the final installed library and checked its
library and skill hashes against source. Evidence is retained under
`evaluations/artifacts/rbs-string-literals/`.

## Verification

| Check | Result |
| --- | --- |
| Core suite on Ruby 3.3.6, 3.4.7 and 4.0.1 | 250 tests / 1,297 assertions per runtime |
| Optional RBS suite on those runtimes | 53 tests / 490 assertions per runtime |
| RBS signature validation on those runtimes | Passed |
| Default locked development bundle | Core suite passed; 130 files linted without offenses |
| `bin/check` | Syntax checks, 2 packaging tests / 76 assertions, and build passed |
| Final installed-gem example | Passing baseline 3/4; suggested missing pair; passing completion 4/4 |
| Unsupported-type probes | `String` and literal-plus-`Object` rejected with exit 2 |

[Matrix commands and environments](evaluations/artifacts/rbs-string-literals/verification/commands.json),
[installed workflow evidence](evaluations/artifacts/rbs-string-literals/agent/command-evidence.json),
and [installed library/skill hashes](evaluations/artifacts/rbs-string-literals/installed-sha256.json)
are retained. Historical Ruby snapshots use `.rb.txt` so they do not join the
active tests or lint scope. Existing method-redefinition fixture warnings and
the gemspec's missing-homepage warning remain; no dependency or lockfile change
is part of this feature.
