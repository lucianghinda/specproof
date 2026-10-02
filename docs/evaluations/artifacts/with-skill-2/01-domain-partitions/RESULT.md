# SpecProof result

## Contract

The explicit requirement in `requirements.md` defines `Checkout#shipping` input `cents` as integer cents in the closed domain `0..100_000` (line 3). The required partitions are `standard: 0..4_999` and `free: 5_000..100_000` (lines 5–6). It excludes output behavior (line 8).

The trusted declaration is in `specifications/checkout.rb`: target at line 1, domain and `exhaustive: true, disjoint: true` at line 2, and partitions at lines 3–4. Those promises follow the explicit complete domain and non-overlapping requirement. The declaration already matched the stated requirements, so it needed no edits.

## Commands and actual results

The first requested-executable invocation, using the environment as received, was:

```sh
/Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --version
```

It failed with `LoadError: cannot load such file -- specproof`. Although the prompt said the environment's gem paths pointed at the isolated installation, the observed `GEM_HOME` and `GEM_PATH` instead pointed to `/Users/luciang/.gem/ruby/4.0.1` and the normal Ruby gem directory. I retried with explicit isolated gem paths:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --version
```

Actual output:

```text
SpecProof 0.1.0
```

Check command:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/checkout.rb --format json
```

Actual JSON:

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"check","errors":[],"contract_digest":"26f4b60e61f1c2010df1ce171b70654fd488bfb2b7b66a2e7a62a713be37528f","findings":[]}
```

Plan command:

```sh
GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/checkout.rb --format json
```

Actual JSON:

```json
{"schema_version":1,"specproof_version":"0.1.0","kind":"plan","errors":[],"contract_digest":"26f4b60e61f1c2010df1ce171b70654fd488bfb2b7b66a2e7a62a713be37528f","criterion":"input-basics-v1","obligations":[{"id":"32865c15c269863d928685b6a84cc812a92a755d2e66e5193ff523fd59c85768","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"0"},"reasons":["input lower endpoint","standard lower endpoint"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/01-domain-partitions/specifications/checkout.rb","line":2},{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/01-domain-partitions/specifications/checkout.rb","line":3}]},{"id":"df89e2ae6451d7b6d5cfab27b0f30a20e281e4226de22c62a6b389af81482782","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"1"},"reasons":["input lower neighbor"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/01-domain-partitions/specifications/checkout.rb","line":2}]},{"id":"fb61899b64abf3f1023dceea1bf7c67137f6d01d3971424e0516a439b335ca28","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"4999"},"reasons":["standard upper endpoint"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/01-domain-partitions/specifications/checkout.rb","line":3}]},{"id":"579d4b656f0d35be7be596b525f74f60aee828af4ea967a10be275fe3ca94a39","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"5000"},"reasons":["free lower endpoint"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/01-domain-partitions/specifications/checkout.rb","line":4}]},{"id":"b21621fbc3f4e33a4f59a060b8dff4959976bdad880ae1c13d95ae3d0f0aa767","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"99999"},"reasons":["input upper neighbor"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/01-domain-partitions/specifications/checkout.rb","line":2}]},{"id":"825eb66ebe4f84255ef719fd28ac24af271da7ee4c543a8f08e2abeac3e33706","target":"Checkout#shipping","input":"cents","value":{"kind":"integer","value":"100000"},"reasons":["input upper endpoint","free upper endpoint"],"sources":[{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/01-domain-partitions/specifications/checkout.rb","line":2},{"path":"/private/tmp/specproof-agent-evaluations/release-skill-2/01-domain-partitions/specifications/checkout.rb","line":4}]}]}
```

The input-basics-v1 boundary candidates cover every planned obligation: `0`, `1`, `4_999`, `5_000`, `99_999`, and `100_000`. Reasons and IDs are retained in the actual plan output above; values are candidates, not a complete or proven test suite. The digest is `26f4b60e61f1c2010df1ce171b70654fd488bfb2b7b66a2e7a62a713be37528f` for both reports.

## Source comparison and uncertainty

The implementation at `checkout.rb:3` uses the threshold `5_000`, so it classifies in-domain values consistently with the requirement's partition boundary. It does not reject values below 0, above 100,000, or non-integer values. The written input contract limits valid inputs but does not state rejection behavior for invalid inputs; whether the implementation is expected to enforce that domain is unresolved. No output behavior or out-of-domain policy was added to the specification.

No tests were present or run; the requested evidence is the SpecProof check and plan.
