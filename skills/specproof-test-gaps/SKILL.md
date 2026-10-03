---
name: specproof-test-gaps
description: Finds untested SpecProof input obligations and adds evidence-backed Minitest coverage for Ruby methods. Use when reviewing boundary or pairwise gaps, integrating SpecProof with Minitest, suggesting allowed assignments, or verifying a fresh coverage report.
---

# Find and close SpecProof test gaps

Use SpecProof plans to find candidate inputs missing from a Minitest suite.
Use an independent requirement or trusted existing test as the expected-result
oracle. SpecProof observes method calls; it does not inspect assertions, replay
tests, infer expected results, or prove application correctness.

## Workflow

1. Read the request, independent behavior requirements, target method, current
   tests, and the input specification. Confirm that the target and parameter
   names match the real method signature. Default scope is strict: every named
   parameter is analyzed. If the task deliberately covers only some inputs,
   every other name must have an explicit `exclude_input :name, reason: "..."`
   declaration, and at least one input must remain analyzed. Do not introduce
   exclusions to make findings, missing obligations, or a strict run disappear.
2. Create or validate the intended input declaration before measuring coverage.
   Run `specproof check PATH --format json`, then
   `specproof plan PATH --format json`; inspect findings, errors, digest, and
   input scope. Resolve or report every finding. Do not change domains,
   partitions, or exclusions merely to make a check or report green. Ask before
   changing the declared contract when its intent is uncertain. Record each
   candidate's stable obligation ID, value,
   and source locations, plus every excluded input and its reason. A plan's
   candidate set covers only its analyzed inputs.
   For a finite-string scenario such as `values: [nil, 1, "user_123"]`, keep
   each value and type exactly as required; `"user_123"` and `:user_123` are
   distinct. Use finite strings only after a fresh plan reports a string value.
   Do not infer support from `0.1.x`, and do not drop or relabel a required
   string to obtain a valid report. If the installed build rejects a required
   string, report that unsupported value rather than substituting a symbol or
   omitting it.
   Use `input-basics-v1` for marginal input candidates unless requirements
   explicitly describe finite joint scenarios. For pairwise coverage, opt in
   with `--criterion pairwise-finite-v1` and require a `combinations` group
   for every target. `all_allowed: true` is an explicit claim that every tuple
   is valid, not a claim of behavioral independence. A `forbid` clause must
   come from a requirement; never add one to erase a missing pair. Pair
   feasibility depends on an allowed full assignment, including all other
   group inputs.
3. Before editing tests or production code, run the intended current suite in a
   fresh process and capture its coverage report as the baseline. Check its run
   ID, digest, input scope, completion, integrity, and original test result.
   Use an intact report to identify existing input evidence; an incomplete
   report cannot establish a baseline gap. Preserve the baseline result as
   recorded, including `tests_passed: false` when the current suite fails.
   For pairwise runs, compare the exact planned pair IDs and typed assignments.
   A method call can satisfy only pairs present together in that valid tuple;
   evidence from separate calls is never combined into a synthetic pair.
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
6. Change production behavior only when the task explicitly authorizes a
   behavior fix. For an authorized fix, add the failing regression assertion
   and capture its failure against the current implementation before making
   the smallest requirement-backed change. For a test-only or review task,
   preserve production code and existing assertions; keep and report a failing
   regression with `tests_passed: false` when the requirement exposes an
   unresolved defect.
7. Rerun the intended test command in a fresh process after the final source or
   test edit. Collection observes calls made during that run only; a previous
   report cannot establish fresh coverage. Verify the newly written report has
   a new `run_id`, the current `contract_digest`, input scope, and obligation
   IDs. Confirm its completion, integrity, actual test result, and
   `scope.targets`, `scope.declaration_sources`, run arguments, and filters
   match the actual test command and loaded test files. `scope.targets` and
   `scope.declaration_sources` are runtime coverage fields; offline check and
   plan results do not have them. If a source changes, run the suite again and
   inspect a fresh report. Compare `scope.completeness_scope` and
   `scope.input_scope` with both the current plan and the actual named runtime
   signature; matching obligation IDs alone do not establish that the analyzed
   scope is the same. Human summaries must disclose excluded names and reasons.
   `100%` means all obligations for analyzed inputs were exercised; it says
   nothing about excluded values or behavior, outputs, interactions, or complete
   method correctness. A matching digest does not fingerprint all source text,
   the full RBS signature, or implementation correctness. Report the actual
   `tests_passed` value and any unresolved finding. Never narrow or exclude
   inputs, weaken strict missing policy, or alter production behavior just to
   turn a failing result green.

For a pairwise baseline, you may use `specproof suggest PATH --report FILE`
after checking the report against a fresh pairwise plan. Suggestions require a
completed, intact report with exact typed obligations, current digest and
declared scope, consistent rows and projections, no errors or unknowns, and a
Boolean original `tests_passed` value. A failing test result is accepted and
preserved. A filtered report supports only its recorded scope. Do not infer
freshness from the digest: it does not include implementation or test bytes,
so run the intended suite again after changes.

Treat each row as an unexecuted, allowed full assignment for the combination
group. Its `covers` field lists missing pair IDs newly covered by that row;
the output has no expected result. Inspect `unassigned_inputs`, which lists
analyzed inputs outside the group and every explicitly excluded parameter,
then supply valid values for those names. Every analyzed input must be valid
before runtime pair evidence counts. Use the independent normative
requirement to write assertions; never generate expected values from the
implementation or the suggestions. Never add exclusions or `forbid` clauses
to erase a gap or make a report green.

When testing a pairwise interaction, derive the expected output from an
independent rule for each combination. A pair coverage hit says only that the
input combination reached the method. Keep the baseline, any newly failing
requirement-backed assertion, and any corrected implementation run in separate
fresh processes, with a fresh report and run ID for each. A passing
`pairwise-finite-v1` report and passing assertions establish evidence only for
the declared finite inputs and assertions; they do not prove exhaustive tuple
coverage or behavioral independence.

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
passing suite alone does not close them. Keep independent input scope intact;
do not exclude an input simply because it has missing obligations or a
non-primitive value.

RBS supplies input types only. It does not supply expected return values or
behavioral output assertions. Derive each assertion from an independent rule
or trusted stated requirement. A coverage candidate or a successful hit
establishes only that an input obligation was exercised; it does not establish
the expected result or prove correctness.

Finite strings are explicitly enumerated text scenarios, not open-ended String
coverage. A supported build accepts only exact String instances containing
valid UTF-8 or US-ASCII text (canonicalized to UTF-8); empty strings,
whitespace, Unicode, and embedded NUL are valid. Invalid bytes, other encodings,
and String subclasses are rejected. No trimming, case folding, or Unicode
normalization occurs. SpecProof copies and freezes owned declaration and
method-entry snapshots without freezing application values; post-entry
mutation cannot change matching. A direct Coverage observation likewise owns
retained strings. Outside-domain string witnesses retain the full string even
though only a bounded number of witnesses are retained. Explicitly selected
RBS string literals and finite unions of supported literals provide exact
scenarios; unrestricted RBS `String` and unions containing unsupported members
remain unsupported and fail atomically. Verify support from a fresh plan; do
not infer it from `0.1.x`.
