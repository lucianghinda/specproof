# Minitest coverage report reference

This reference targets SpecProof `0.1.x`, JSON schema `1`, and
`input-basics-v1`, using Minitest `>= 5.26.2` and `< 5.28.0` on CRuby `3.3`,
`3.4`, or `4.0`. The package/runtime major and minor versions must match.
Prefer `~> 5.26.2` when using published packages; a mislabeled package is
rejected even when its metadata alone falls within the supported range.
Confirm `specproof --version` and `specproof_version`; report unsupported
versions instead of guessing field meanings.

Run the full test suite as a fresh process, for example:

```sh
bundle exec rake test
```

Prefer the repository's existing full-suite command when available. Do not
filter the suite when claiming total project coverage. The adapter measures
direct calls to supported methods during the original Minitest run. It does not
inspect assertions or replay tests. Unsupported signatures, collector errors,
and out-of-domain inputs cannot be counted as successful obligation evidence.

After the declaration passes check and plan, capture a fresh report from the
intended current test suite before editing tests or production code. Inspect its
`run_id`, digest, input scope, completion, integrity, and `tests_passed` value.
An incomplete report cannot establish that an obligation was absent; preserve
the observed test result even when it is false. Use an intact report as the
baseline for existing input evidence.

The report's `scope.input_semantics` is `effective_bound_values`, and
`scope.argument_presence` is `not_observed`. By default, every named required or
optional positional/keyword parameter must be analyzed. A deliberately narrow
input scope must still account for every name: use an explicit
`exclude_input :name, reason: "..."` for each excluded parameter, and keep at
least one analyzed input. There is no wildcard or implicit exclusion. Excluded
values are not read; selected non-primitive values, including defaults, make
collection incomplete. Do not hide those failures by narrowing or relabeling a
run. Ruby applies defaults before the observed entry; omitted and explicitly
equal analyzed values exercise the same obligation. A raising default before
entry supplies no target entry evidence. Never claim omission coverage from a
nil/default-value hit.

Successful offline check/plan and runtime coverage reports all include
`scope.completeness_scope: "analyzed_inputs"` and `scope.input_scope`. Each entry
contains a `target`, `analyzed_inputs` names, and `excluded_inputs` records with
`name`, `reason`, and declaration `source` (`path`, one-based `line`, `kind`).
Check/plan scope describes only the declaration. Runtime-only
`scope.targets` and `scope.declaration_sources` identify composed targets and
invocation declaration paths; they do not prove which test files ran.
Always compare the fresh report's contract digest and input scope with the
current plan and intended method signature. A matching set of obligation IDs
does not by itself prove a matching scope. Human reports must name excluded
inputs and reasons.

The obligation denominator includes analyzed inputs only. Thus `100%` means
that every candidate for those inputs was exercised during the reported run; it
says nothing about excluded values or behavior, output assertions, interactions,
or complete method correctness. An intentionally filtered scenario report may
establish only that explicitly named run scope, never total project coverage.

For a mixed DSL/RBS target, pass the same explicit source options to the
adapter that you used for offline check and plan:

```ruby
SpecProof::Minitest.install!(
  specifications: ["spec/registration.rb"],
  rbs: ["sig/registration.rbs"],
  targets: ["Registration#eligible?"],
  output: "tmp/specproof-coverage.json",
  fail_on_missing: false
)
```

For RBS-only input, use `specifications: []` and supply both non-empty `rbs:`
and `targets:` arrays. Pass `--rbs FILE` and `--target 'Class#instance_method'`
to offline `check` and `plan`; repeat either option for additional files or
targets. Check/plan documents contain no runtime scope fields. Only inspect
`scope.targets` and `scope.declaration_sources` on a fresh coverage report.

Parse the generated JSON and require all of the following before claiming the
current suite covered its plan:

- `schema_version` is `1` and `kind` is `"coverage"`.
- `criterion` is `"input-basics-v1"` and `contract_digest` matches a fresh
  `specproof plan PATH --format json` report for the same specifications.
- `run_id` is present and belongs to the latest full-suite execution; confirm
  it matches the run summary emitted by that invocation.
- For imported declarations, `scope.targets` lists the composed runtime
  targets, while `scope.declaration_sources` records canonical DSL paths, RBS
  paths, and explicitly selected RBS targets. Compare these values with the
  actual adapter configuration and the test command you ran. They do not
  attest which test files the command loaded.
- `scope` describes the intended full run, with no test-name inclusion filter
  or exclusion pattern. Inspect its original `arguments` as well as `filter`
  and `exclude`; the report cannot attest which test files the caller loaded.
- `completion` is `"completed"`, `integrity` is `true`, and `errors` and
  `incomplete_reasons` are empty. Record `tests_passed` independently from
  coverage status.
- `unknown_count` and `missing_count` are zero, `outside_domain` is empty, and
  every expected obligation ID appears with status `"exercised"` and a positive
  hit count.

The suite's test result is separate from coverage status. Require
`tests_passed: true` when claiming a successful suite run. If it is false, report
the failing assertions and preserve that result. Change production behavior
only when the task explicitly authorizes a behavior fix; for test-only or review
work, keep the regression failure and do not weaken strict missing policy or
alter input scope to make the run green.

The `missing` array lists candidates with no observed calls. `unknown_count`
and incomplete reports mean collection could not establish a result. Keep both
states open. Do not treat zero missing values in a stale report as current
evidence. Compare the fresh digest and run ID, and re-run the whole suite after
any source, specification, or test change.

When a newly added boundary assertion exposes a bug and the task explicitly
authorizes a behavior fix, preserve the red result from the old implementation,
fix the method using the independent requirement, then run the full suite
again. For test-only or review work, preserve production code, keep the failing
regression, and report the unresolved finding with `tests_passed: false`. In
either case, retain the failing-run evidence in the task summary and report the
actual result from the final fresh run.
