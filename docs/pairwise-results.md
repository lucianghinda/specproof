# Finite pairwise coverage

The opt-in `pairwise-finite-v1` criterion derives obligations from explicit
finite input domains and a declared combinations group. `all_allowed: true`
admits the full Cartesian product; partial `forbid` assignments remove matching
full tuples. A pair is required only when an allowed full assignment contains
it. No implementation behavior is used to invent restrictions or expected
results.

The existing collector supplies whole calls. Calls cannot combine their
individual values to manufacture a pair hit. Every analyzed input must be in
its domain, including inputs outside the selected pairwise group. A forbidden
call earns no hits under either criterion and is recorded as outside the joint
domain. This does not make a deliberate negative test fail.

The scalar criterion remains the default. Scalar IDs and contract digests
without combinations metadata retain their previous representation. Typed
pair IDs distinguish strings from symbols, and equivalent declaration/rule
orders keep identity stable. Rule provenance survives duplicate declarations.

## Demonstrated value

The runnable [delivery example](../examples/pairwise/README.md) starts with
passing assertions for `00`, `01`, and `10`. Both values of each input appear,
but pair coverage is only 3/4. The missing `11` assertion, derived from the
separate requirements, exposes the faulty notification result. Coverage then
reaches 4/4 while `tests_passed` remains false. A separate corrected
implementation passes all four assertions.

The constrained declaration requires three pairs and explains the excluded
fourth. The three-input example covers all 12 pair rows with four calls; it
does not cover all eight full assignments. The [agent workflow exercise](evaluations/pairwise-skills.md)
records how the exported skills guide a fresh actor through a missing-pair
test without narrowing the contract to hide the defect.

## Review and limits

Independent Luna specification review found that the global obligation limit
was checked after retaining every target's pair space. Planning now checks the
running count before retaining each space and stops on the first crossing.
A regression verifies that later targets are not planned after that error.
Quality review found no functional defect in the reviewed implementation.

Enumeration is limited to 10,000 complete assignments and 10,000 possible pair
rows per target, with at most 10,000 required pair obligations in a plan.
These are explicit configuration errors, not sampling. Excluded-pair metadata
is bounded per target, but not globally: many heavily constrained targets can
still produce a large combined report. This remains a resource limitation for
large projects.

This release supports one finite combinations group per target. It does not
generate test suites, infer business constraints, solve arbitrary Ruby
predicates, measure higher-order interactions, or prove assertion adequacy.
RBS can supply finite inputs to a combinations-only declaration; its existing
supported type subset is unchanged.

## Verification

The final implementation passed the following local checks:

| Check | Result |
| --- | --- |
| Core suite on Ruby 3.3.6, 3.4.7, 4.0.1 | 207 tests, 1,044 assertions per runtime |
| Optional RBS suite on those runtimes | 47 tests, 436 assertions per runtime |
| `rbs -I sig validate` on those runtimes | Passed |
| Default locked development bundle, `bundle exec rake` | Core suite passed; 115 files linted without offenses |
| `bin/check` | Syntax checks, 2 packaging tests / 76 assertions, and gem build passed |
| Fresh example processes | Initial 3/4 passing; gap 4/4 failing assertion; corrected 4/4 passing; three-input 12/12 passing |
| Constrained CLI plan | 3 required pairs, 1 explained exclusion |

CI's optional suite command now includes every `test/rbs/*_test.rb` file.
Existing method-redefinition fixture warnings and the gemspec's missing-homepage
warning remain; neither is a new failure. No dependency was added.

To keep the existing complexity budgets, option parsing, coverage projections,
and report formatting use small helpers. The full regression suite covers the
preserved scalar behavior and adapter lifecycle; no lint threshold was raised.
