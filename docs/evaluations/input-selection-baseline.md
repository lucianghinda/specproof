# Input-selection skill baseline

Before updating the packaged skills, a fresh native subagent was requested with
model `gpt-6-luna`, high reasoning, and no inherited conversation. This records
the requested routing and returned response, not a server-side model attestation.
The actor was allowed to read only the existing `specproof-specify` skill and its
bundled usage reference. It ran no application tests and edited no files.

## Supplied scenario

> I want SpecProof to measure only file_id=nil and file_id=1 in
> PStoreLogger#save(data,file_id:nil), deliberately leaving payload contents
> outside this analysis. Existing tests pass Hash payloads. Write the exact
> specification and describe what a passing report would establish. Use only
> commands/declarations documented by the supplied skill; don't invent API.

## Returned response

> I can’t give a compliant exact declaration from the supplied baseline. The
> skill requires declaring every method parameter and forbids partial
> obligations for unsupported inputs, but it documents no `Hash` domain for
> `data`. It also says finite scalar arrays are supported without documenting
> their declaration syntax, so I can’t supply a syntax such as
> `values: [nil, 1]` under the instruction not to invent API.
>
> A clean `check` would establish that the declared domains and partitions have
> no reported gap, overlap, empty-domain, or out-of-domain findings. A `plan`
> would propose candidates under `input-basics-v1`. Neither would prove runtime
> test loading, method correctness, payload behavior, or complete test
> coverage; the digest fingerprints normalized input domains and partition
> policies.
>
> I read only the specified skill and its documented `references/usage.md`.

## Interpretation

The actor could not complete the requested scoped authoring task using the old
skill. Its statement about missing finite-value syntax is retained as returned,
not treated as a verified documentation finding. The relevant product gap is
that the old skill requires every parameter to be analyzed and documents no
explicit exclusions. This single qualitative baseline does not establish an
agent reliability rate or isolate a causal effect of the later skill update.
