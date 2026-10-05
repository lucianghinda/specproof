# RBS-backed registration example

This example imports `age: Integer` and optional nullable `consent: bool?`
from [the explicit RBS signature](sig/registration.rbs), then uses the DSL
only to refine age to `0..120` with complete, non-overlapping minor/adult
partitions. The independent rule is in [requirements.md](requirements.md): an
applicant is eligible exactly when age is at least 18 and consent is true.
Missing consent and explicit false both deny eligibility.

The composed plan has nine marginal obligations: six age candidates
(`0`, `1`, `17`, `18`, `119`, `120`) and three consent values (`nil`, `false`,
`true`). The nine obligations do not mean nine combinations and do not state
any expected return value.

Run all commands from the gem directory. The RBS parser is in the explicit
optional bundle. Every command starts a fresh Ruby process. Offline check and
plan emit JSON to stdout; the three runtime checkpoints below write separate
coverage reports under `/private/tmp`:

```sh
cd gems/specproof
BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -Ilib exe/specproof check examples/rbs_registration/specification.rb --rbs examples/rbs_registration/sig/registration.rbs --target 'Registration#eligible?' --format json
BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -Ilib exe/specproof plan examples/rbs_registration/specification.rb --rbs examples/rbs_registration/sig/registration.rbs --target 'Registration#eligible?' --format json
```

The baseline implementation uses `age > 18`. It tests every declared age
candidate except 18, across each consent value. Its meaningful assertions
follow the written eligibility rule, and its fresh report should show eight of
nine marginal obligations exercised, with only the age-18 obligation missing:

```sh
SPEC_PROOF_REPORT=/private/tmp/registration-baseline.json CHECKPOINT=baseline BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -I examples/rbs_registration/implementations/age_gt examples/rbs_registration/test_registration.rb
```

Run the added age-18 assertion alongside the passing baseline cases against
that same faulty implementation. The assertion should fail because an
18-year-old who consents is eligible under the stated rule. The report should
show all nine candidates hit but `tests_passed: false`, demonstrating that
input coverage alone does not establish correctness:

```sh
SPEC_PROOF_REPORT=/private/tmp/registration-boundary-red.json CHECKPOINT=boundary BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -I examples/rbs_registration/implementations/age_gt examples/rbs_registration/test_registration.rb
```

The final checkpoint loads the separate corrected implementation (`age >= 18`)
and tests all six age candidates with all three consent values. Its new report
should have a distinct run ID and all nine unchanged obligations exercised:

```sh
SPEC_PROOF_REPORT=/private/tmp/registration-corrected.json CHECKPOINT=complete BUNDLE_GEMFILE=Gemfile.rbs bundle exec ruby -I examples/rbs_registration/implementations/age_gte examples/rbs_registration/test_registration.rb
```

Inspect each fresh report's digest, obligation IDs, run ID, completion,
integrity, `tests_passed`, and declaration scope. The digest covers normalized
input domains and partition policy; it does not fingerprint all source text,
the full signature, or implementation correctness. A passing input-coverage
report is evidence that candidates reached the method, while the behavior
assertions and their independent rule establish expected results.
