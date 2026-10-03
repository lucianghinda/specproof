# Finite string values implementation plan

**Goal:** Measure explicitly enumerated text values using the existing finite-domain workflow.

**Architecture:** Extend the existing scalar value representation, domain checker, planner and observer. No new criterion, dependency, CLI option or general String type inference.

## Decisions and boundaries

The user approved exact finite string values, stable identities, immutable storage, typed reporting, updated skills and a real pilot. Preserve the existing meanings of outside-domain tuples and incomplete collection.

- Accept exact String instances containing valid UTF-8 or US-ASCII text. Canonicalize US-ASCII to UTF-8 without changing text; no case folding, trimming, Unicode normalization or arbitrary encoding transcoding. Reject invalid byte sequences, other encodings and String subclasses explicitly. Empty strings, whitespace, Unicode and embedded NUL are valid text values.
- Copy and freeze declared strings and observed strings; never freeze or mutate application-owned strings. Runtime matching uses the entry snapshot, even when the method subsequently mutates its argument. Direct Coverage observation must also own any retained witness.
- Deduplicate and order strings deterministically after existing scalar types. Strings and symbols with the same spelling remain distinct. Existing nonstring IDs and digests remain byte-identical.
- JSON uses `{kind: "string", value: "..."}`; human output quotes/escapes strings. This adds a value kind under existing schema version 1 and input-basics-v1; document that consumers must handle this kind.
- Preserve bounded witness counts; no event trace. A retained outside-domain string witness is an immutable full string, so the existing count bound is not a byte bound.
- Support finite string partitions and source-neutral finite type constraints consistently. RBS string types and literals remain unsupported in this milestone, including mixed unions; do not accidentally widen the RBS adapter through shared primitive helpers.
- Excluded object arguments remain unread. Method-shape, lifecycle, strict defaults and actual test outcomes are unchanged.
- No regular expressions, lengths, open-ended strings, arbitrary bytes, Sorbet, pairwise coverage or output contracts.

## Task 1 — core behavior

Files: lib/specproof/{model,domains,coverage,collector,report,type_constraints}.rb, sources/rbs_projector.rb only if required to preserve its boundary, sig/specproof.rbs; focused tests.

- [x] Add failing tests for mixed strings/symbols, deterministic ordering and identity, mutation isolation, text encodings, partitions, typed reporting, and legacy digest/ID preservation.
- [x] Implement a shared supported-string validation/copy path using existing domain helpers rather than introducing a parallel domain class. Use it consistently at declaration and runtime boundaries.
- [x] Add failing entry-mutation and direct-observer witness tests, then implement owned snapshots. Assert valid outside-domain strings remain outside-domain evidence; unsupported text makes collector incomplete.
- [x] Assert RBS string literals/types still fail atomically and source-neutral constraints compose correctly.
- [x] Run core, optional RBS and lint checks. Obtain independent specification review followed by quality review and fix findings.

## Task 2 — usage and adoption

Files: README.md, docs/report-format.md, skills/specproof-{specify,test-gaps}/, docs/finite-strings-results.md, docs/pilots/finite-strings/.

- [x] Explain supported encodings, exact finite scenarios, snapshot ownership, report value kind and remaining RBS limits; update shipped agent guidance.
- [x] Copy the retained ordinary PStoreLogger source/tests into scratch without altering the originals. Declare file_id values [nil, 1, "user_123"] with the data payload excluded.
- [x] Run unchanged tests and record a valid 2/3 report, not a manufactured green result. Add a separate assertion based on its documented string-ID behavior; record a fresh 3/3 report and actual test outcomes.
- [x] Retain concise reproducible pilot evidence and source hashes; no dependency trees. Check installed package and exported skills.

## Task 3 — completion

- [x] Run core and optional suites plus signatures on Ruby 3.3.6, 3.4.7 and 4.0.1; lint, bin/check and diff checks.
- [x] Summarize files changed, simplifications, verification and limits; commit using Lore protocol on implement/finite-strings. Leave main unchanged.
