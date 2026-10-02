# SpecProof result

## Contract and source review

The written contract in `requirements.md` (lines 3–6) defines integer cents in
`0..100_000`, with `standard` at `0..4_999` and `free` at `5_000..100_000`.
It explicitly excludes output behavior.

The existing declaration in `specifications/checkout.rb` (lines 1–6) targets
`Checkout#shipping`, declares `cents: 0..100_000` with `exhaustive: true` and
`disjoint: true`, and declares those same two partitions. This matches the
written input contract. No specification change was needed.

`checkout.rb` lines 2–3 compares `cents` against `5_000`, so for integer cents
inside the stated domain the threshold agrees with the two written partitions.
The method does not validate the declared integer type or bounded domain; its
implementation accepts other values according to Ruby comparison behavior.
Thus the requirements' input domain is a contract boundary, not an enforced
precondition in the implementation. No behavior outside that domain is
specified here.

## Invocation and verification

The first invocation with the ambient environment failed with
`LoadError: cannot load such file -- specproof`; the ambient `GEM_HOME` and
`GEM_PATH` pointed at the user gem directories. Retrying with both variables
set to `/private/tmp/specproof-validation-gems` loaded the requested isolated
installation and succeeded.

Commands run from the workspace root:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/checkout.rb --format json
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/checkout.rb --format json
```

`check` result:

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"check","errors":[],"contract_digest":"26f4b60e61f1c2010df1ce171b70654fd488bfb2b7b66a2e7a62a713be37528f","findings":[]}
```

`plan` result:

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"plan","errors":[],"contract_digest":"26f4b60e61f1c2010df1ce171b70654fd488bfb2b7b66a2e7a62a713be37528f","criterion":"input-basics-v1","obligations":[{"id":"32865c15c269863d928685b6a84cc812a92a755d2e66e5193ff523fd59c85768","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"0"},"reasons":["input lower endpoint","standard lower endpoint"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-2/01-domain-partitions/specifications/checkout.rb","line":2},{"path":"/private/tmp/specproof-agent-evaluations/with-skill-2/01-domain-partitions/specifications/checkout.rb","line":3}]},{"id":"df89e2ae6451d7b6d5cfab27b0f30a20e281e4226de22c62a6b389af81482782","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"1"},"reasons":["input lower neighbor"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-2/01-domain-partitions/specifications/checkout.rb","line":2}]},{"id":"fb61899b64abf3f1023dceea1bf7c67137f6d01d3971424e0516a439b335ca28","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"4999"},"reasons":["standard upper endpoint"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-2/01-domain-partitions/specifications/checkout.rb","line":3}]},{"id":"579d4b656f0d35be7be596b525f74f60aee828af4ea967a10be275fe3ca94a39","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"5000"},"reasons":["free lower endpoint"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-2/01-domain-partitions/specifications/checkout.rb","line":4}]},{"id":"b21621fbc3f4e33a4f59a060b8dff4959976bdad880ae1c13d95ae3d0f0aa767","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"99999"},"reasons":["input upper neighbor"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-2/01-domain-partitions/specifications/checkout.rb","line":2}]},{"id":"825eb66ebe4f84255ef719fd28ac24af271da7ee4c543a8f08e2abeac3e33706","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"100000"},"reasons":["input upper endpoint","free upper endpoint"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/with-skill-2/01-domain-partitions/specifications/checkout.rb","line":2},{"path":"/private/tmp/specproof-agent-evaluations/with-skill-2/01-domain-partitions/specifications/checkout.rb","line":4}]}]}
```

The plan uses `input-basics-v1` and proposes boundary candidates
`0`, `1`, `4_999`, `5_000`, `99_999`, and `100_000`. These are candidates
derived from the declared domain and partition boundaries, not a complete or
proven test suite. There are no SpecProof errors or semantic findings.

## Artifacts and uncertainty

- Added `RESULT.md` with the source review, invocation record, and unmodified
  command JSON reports.
- `specifications/checkout.rb` was already aligned with the requirements and
  was not changed.
- Uncertainty: requirements define a bounded integer input but do not require
  runtime validation. The implementation does not enforce that bound; behavior
  outside the contract remains unspecified.
