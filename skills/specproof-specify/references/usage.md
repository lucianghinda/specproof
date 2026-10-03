# SpecProof command and report reference

This reference targets SpecProof `0.1.x`, JSON schema `1`, and
`input-basics-v1`. Confirm `specproof --version` and the report's
`specproof_version`, but do not infer finite-string support from a `0.1.x`
version alone. A fresh `plan` from the installed build must accept the
declaration and report a typed string value; otherwise preserve the requested
value and report that the build does not support it. Report unsupported
versions or value kinds instead of guessing field meanings.

Pairwise finite planning is opt-in and supported when the installed build
accepts `--criterion pairwise-finite-v1`. The default remains
`input-basics-v1`; verify the actual `criterion` in every report rather than
inferring it from a package version. A pairwise plan requires a `combinations`
group for every target.

Run commands from the application project and use its normal Ruby/Bundler
environment:

```sh
specproof check spec/registration.rb --format json
specproof plan spec/registration.rb --format json
```

For a mixed DSL/RBS declaration, repeat `--rbs FILE` for supplied RBS files
and `--target 'Class#instance_method'` for each selected target. RBS requires
at least one explicit target, and a target without an RBS file is an error.
Keep both options the same across check and plan:

```sh
bundle exec specproof check spec/registration.rb --rbs sig/registration.rbs --target 'Registration#eligible?' --format json
bundle exec specproof plan spec/registration.rb --rbs sig/registration.rbs --target 'Registration#eligible?' --format json
```

For an RBS-only contract, omit the positional DSL path and retain both explicit
RBS options:

```sh
bundle exec specproof plan --rbs sig/registration.rbs --target 'Registration#eligible?' --format json
```

`check` returns declared gap, overlap, empty-domain, and out-of-domain findings.
It cannot decide which of two conflicting policies is intended. `plan` requires
a specification with no semantic findings and uses the `input-basics-v1`
criterion. It proposes domain endpoints, neighboring values, and declared
partition boundaries; its output is a set of candidates for review.

For pairwise finite scenarios, declare one `combinations` group per target and
select the criterion explicitly:

```ruby
SpecProof.define "DeliveryOptions#build" do
  input :expedited, values: [false, true]
  input :notify, values: [false, true]
  combinations :expedited, :notify, all_allowed: true
end
```

`all_allowed: true` explicitly says every tuple is valid; it does not establish
behavioral independence. Alternatively, use a nonempty block containing only
requirement-backed `forbid` assignments. A partial assignment forbids every
matching completion. Rules are data, never executable predicates. Never add a
restriction just to remove a missing pair. A pair is required only if it has
an allowed full assignment as a completion, so feasibility must account for
all group inputs. A forbidden tuple with three inputs can still contain
individually feasible pairs.

The CLI form is
`specproof plan PATH --criterion pairwise-finite-v1 --format json`. `check`
does not accept a criterion. Pairwise plans require a group for every supplied
target and reject oversized domains rather than sampling them.

JSON reports use `schema_version: 1`. Check reports include `kind: "check"`,
`contract_digest`, and `findings`. Plan reports include `kind: "plan"`, the
same digest, `criterion`, and `obligations`. Every planned obligation has a
stable `id`, target, input name, typed value, reasons, and source locations.
Integer values are decimal strings inside a typed value object. Compare the
digest when comparing reports; compare obligation IDs when linking tests to
planned values. Re-run the current command before relying on old output.
Finite strings add `{ "kind": "string", "value": "..." }` under schema 1.
Consumers must handle this kind wherever typed values and witnesses occur.

For `pairwise-finite-v1`, each obligation instead has an `inputs` object with
two input names mapped to typed values; the row also has the shared stable ID,
target, reasons, and source locations. Pair names are sorted canonically.
`excluded_pairs` lists typed pairs with no allowed full completion, their
`no_allowed_completion` reason, and relevant constraint sources. These pairs
are excluded from the denominator. Runtime rows add status and hit counts to
the planned pair fields. A forbidden runtime tuple satisfies no pair
obligations. Keep pair coverage separate from test assertions and output
correctness.

Use only the declaration forms supported by SpecProof:

```ruby
SpecProof.define "Checkout#shipping" do
  input :cents, range: 0..100_000, exhaustive: true, disjoint: true do
    partition :standard, range: 0..4_999
    partition :free, range: 5_000..100_000
  end
end
```

When finite-string support is present, enumerate exact text values with
`values`, for example `values: [nil, 1, "user_123"]`. This is a finite scenario
subset, not a model of all strings. Symbols and strings with the same spelling
are distinct values. Only exact `String` instances containing valid UTF-8 or
US-ASCII are accepted; US-ASCII is canonicalized to UTF-8. Empty strings,
whitespace, Unicode, and embedded NUL are valid. Invalid bytes, other encodings,
and String subclasses are rejected. Values are not trimmed, case-folded, or
Unicode-normalized. SpecProof owns frozen copies of declared strings and
observed entry values, so mutating an application argument after method entry
does not alter matching or freeze the application's string. A retained
outside-domain string witness is full-sized even though witness count is
bounded.

Do not add inferred partitions to close a gap or remove an overlap. Explain
the witnesses and ask for the intended policy.

Successful check and plan reports both include
`scope.completeness_scope: "analyzed_inputs"` and `scope.input_scope`. Each
scope entry contains a target, its `analyzed_inputs` names, and any
`excluded_inputs` with a name, reason, and declaration source. By default every
named runtime parameter is analyzed. An intentionally partial contract must
explicitly exclude every remaining named parameter with a reason and retain at
least one analyzed input; there are no wildcards or implicit exclusions. For
an RBS-selected target, DSL `input` and `exclude_input` names must match its
signature. An exclusions-only DSL declaration is valid when supported finite
inputs can be imported from RBS. A type-only unsupported input may be excluded
only by an explicit declaration; an unsupported selected union remains an
atomic error.

The report digest represents normalized behavioral domains, partition
policies, and sorted excluded names. Exclusion reason/source and declaration
order do not affect it. No-exclusion digests and obligation IDs remain stable.
It does not fingerprint all DSL source text, the full RBS signature, or
implementation correctness. Provenance source objects require `path` and
`line`; schema 1 permits additional fields, so consumers must tolerate unknown
fields. A source's `kind` identifies its family but does not change obligation
identity. Read the coverage reference for runtime `declaration_sources` and
collection scope; offline check/plan scope describes the declaration and does
not attest runtime binding or that tests loaded.
RBS string types and string literals remain unsupported, including inside
unions; these selected inputs fail atomically even when DSL finite strings are
supported.

## Pairwise suggestions

After an intact runtime coverage report records missing pair obligations, ask
SpecProof for allowed group assignments with:

```sh
specproof suggest spec/delivery.rb --report tmp/coverage.json --format json
specproof suggest --rbs sig/delivery.rbs --target 'Delivery#build' spec/delivery.rb --report tmp/coverage.json --format json
```

There must be exactly one nonempty `--report`. The command always uses
`pairwise-finite-v1` and `greedy-pairwise-v1`; it rejects `--criterion` and
does not add a new default to check or plan. It replans the supplied current
declarations, then checks schema 1, `kind: "coverage"`, the pairwise
criterion, digest, exact target and analyzed/excluded/group scope, exact typed
obligation denominator, row statuses/hits, counters, and missing/exercised
projections. The report must be completed, intact, free of errors and
incomplete reasons, and have no unknown observations. `tests_passed` must be a
Boolean; `false` is retained as the actual test outcome rather than rejected.
Filtered reports are usable only for their recorded scope.

The output retains `source_run_id`, `source_tests_passed`, and `source_scope`.
It marks `assignment_scope: "combination_group"` and
`minimality: "not_guaranteed"`. Each suggestion has a typed full group
assignment and `covers` lists only newly covered missing IDs. The rows' union
must equal the source missing set. `unassigned_inputs` lists every analyzed
parameter outside the group and every explicitly excluded parameter; the
caller remains responsible for supplying those values. Runtime evidence still
requires all analyzed inputs to be valid.

No candidate is executed and no expected output is inferred. Use a separate
requirement as the assertion oracle before writing an assertion. The digest
does not fingerprint implementation or test files; rerun the intended suite in
a fresh process after either changes and inspect its new run ID and result.
Generation rejects reports over 32 MiB and work over 10,000 cumulative full
assignments, 10,000 cumulative possible pair rows, or 1,000,000 candidate-to-pair
memberships. It never truncates or returns partial suggestions.
