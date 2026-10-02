---
name: specproof-test-gaps
description: Finds untested SpecProof input obligations and adds evidence-backed Minitest coverage for Ruby methods. Use when reviewing boundary test gaps, integrating SpecProof with Minitest, or verifying a fresh coverage report.
---

# Find and close SpecProof test gaps

Use SpecProof plans to find candidate inputs missing from a Minitest suite.
Use an independent requirement or trusted existing test as the expected-result
oracle. SpecProof observes method calls; it does not inspect assertions, replay
tests, infer expected results, or prove application correctness.

## Workflow

1. Read the request, independent behavior requirements, target method, current
   tests, and the input specification. Confirm that the target and each
   argument name match the real method signature.
2. Run `specproof check PATH --format json` and inspect `findings`, `errors`,
   and `contract_digest`. Resolve or report every finding. Do not change the
   input domain or partition promises just to make the check green. Ask before
   changing the declared contract when its intent is uncertain.
3. Run `specproof plan PATH --format json`. Record each candidate's stable
   obligation ID, value, and source locations. Map candidates to existing
   assertions and identify which obligations lack executable evidence.
4. For each uncovered value, derive its expected result from an independent
   normative requirement or source document. A trusted existing test can
   preserve the exact case it states, but cannot establish a general boundary
   rule from one example. If there is no oracle, ask a precise question and do
   not invent an assertion. A candidate value alone does not say what the
   method should return.
5. Add a meaningful assertion for each agreed gap. Keep the obligation ID and
   the normative requirement/source location beside the assertion, such as in
   its failure message. Identify the implementation method as the code under
   test, not as the source of expected behavior. Preserve every existing domain
   obligation unless an independently justified requirement change is explicit.
6. For a behavior fix, first add the failing regression assertion and run it
   against the current implementation. Capture the failure. Then make the
   smallest implementation change supported by the requirement and rerun that
   test to confirm it passes.
7. Rerun the full suite in a fresh command after the final edit. Collection
   observes calls made during that run only; a previous report cannot establish
   fresh coverage. Verify the generated report against the current plan before
   making a completion claim.

For adapter setup, report fields, and evidence checks, read
[the bundled coverage report reference](references/usage.md).

## Minitest adapter setup

Keep Minitest in the application's test environment and use the supported
version range `>= 5.26.2` and `< 5.28.0`, with matching package/runtime major
and minor versions. Prefer `~> 5.26.2` for ordinary published packages.
Require application code and Minitest before installing the
adapter. Install it once in the suite entrypoint:

```ruby
require "minitest/autorun"
require "registration"
require "specproof/minitest"

SpecProof::Minitest.install!(
  specifications: ["spec/registration.rb"],
  output: "tmp/specproof-coverage.json",
  fail_on_missing: false
)
```

Use `fail_on_missing: false` when first adding the adapter to a suite with no
established missing-obligation policy, so gaps can be reported without changing
the suite's existing pass/fail behavior. Preserve an existing
`fail_on_missing: true` policy; the adapter still writes its report when
unobserved obligations make the run fail. Never disable that strict policy just
to obtain a green result. Use the report to decide whether gaps remain; a
passing suite alone does not close them.
