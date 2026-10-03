# SpecProof command and report reference

This reference targets SpecProof `0.1.x`, JSON schema `1`, and
`input-basics-v1`. Confirm `specproof --version` and the report's
`specproof_version` before applying it; report unsupported versions instead of
guessing field meanings.

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

JSON reports use `schema_version: 1`. Check reports include `kind: "check"`,
`contract_digest`, and `findings`. Plan reports include `kind: "plan"`, the
same digest, `criterion`, and `obligations`. Every planned obligation has a
stable `id`, target, input name, typed value, reasons, and source locations.
Integer values are decimal strings inside a typed value object. Compare the
digest when comparing reports; compare obligation IDs when linking tests to
planned values. Re-run the current command before relying on old output.

Use only the declaration forms supported by SpecProof:

```ruby
SpecProof.define "Checkout#shipping" do
  input :cents, range: 0..100_000, exhaustive: true, disjoint: true do
    partition :standard, range: 0..4_999
    partition :free, range: 5_000..100_000
  end
end
```

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
