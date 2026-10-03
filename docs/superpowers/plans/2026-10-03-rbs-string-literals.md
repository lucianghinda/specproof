# RBS string-literal input implementation plan

**Goal:** Import finite RBS string-literal input domains without repeating their values in the DSL.

**Architecture:** Extend the existing literal projection to the existing supported string predicate. Reuse canonical domain ownership, union composition, refinements, provenance, pairwise planning, collection and suggestions. No new dependencies, report schema, criterion or output analysis.

**Approved scope:** The user approved the previously presented RBS literal-union example and requested implementation with Luna subagents. Work on `implement/rbs-string-literals`; leave main unchanged until a later merge request.

```rbs
class DeliveryOptions
  def build: (country: ("ro" | "de"), expedited: bool) -> untyped
end
```

```ruby
SpecProof.define "DeliveryOptions#build" do
  combinations :country, :expedited, all_allowed: true
end
```

The above produces four pair obligations. Three observed combinations can leave
`country="de", expedited=true`; the existing suggestion API supplies that input
assignment, without generating expected behavior.

## Semantics

- Accept individual string literals, literal unions, optional literals and unions with the already supported primitives. Own immutable canonical UTF-8 snapshots using the existing domain implementation; keep empty strings, whitespace and valid Unicode exact.
- Preserve the difference between `"ro"` and `:ro`. Deduplicate and order through existing domain rules so equivalent RBS union ordering keeps obligation IDs and digests stable.
- Use existing DSL refinement/subset checks and RBS provenance. A conflicting value reports the existing domain/type diagnostic.
- Unrestricted `String`, aliases, object/collection types and other unsupported selected union members remain unsupported. Never silently project only the supported part of a union. Explicit input exclusions retain existing behavior.
- String encoding/validation follows `Domains.supported_string?`; invalid or unsupported literal values fail as `unsupported_rbs_type`, with source information. Do not invent escape behavior: inspect what the supported RBS 4.2.0 parser actually supplies.
- Return signatures remain outside analysis. No inference of allowed combinations or expected results.
- Read RBS source files as UTF-8, matching RBS 4.2.0's own environment loader. Regression testing exposed locale-dependent literal interpretation with the previous default-encoding read; Unicode literals and escapes must retain their meanings under a US-ASCII external encoding too.

## Implementation and verification

- [x] Core owner: in `test/rbs/source_test.rb`, replace obsolete string-literal rejection expectations and add focused literal, nullable/mixed union, string/symbol identity, exact text, immutable ownership, stable order, refinement and atomic unsupported-union cases. Run red before implementing the minimal projection change in `lib/specproof/sources/rbs_projector.rb`. Reuse `Domains.supported_string?` rather than adding a parallel string validator. In `lib/specproof/sources/rbs.rb`, load UTF-8 explicitly and verify public loading across external encodings.
- [x] Integration owner: add `test/rbs/string_literals_workflow_test.rb` using existing optional-suite conventions. Exercise real parser, combinations-only DSL, four-pair plan, Minitest report and CLI suggestions from three calls. Assert missing typed string, expected suggestion, source provenance, unchanged input files, and unrestricted String/unsupported union atomic errors. Expected test outcomes must come from a fixture requirement, never inferred by SpecProof.
- [x] Documentation owner: update current README, RBS status/report reference, both agent skills and usage references as needed, and CHANGELOG. Add a compact runnable `examples/rbs_string_literals/` with requirements, signature, combinations-only declaration, original tests, separate gap test and runner. Update current string-literal rejection wording; leave historical evidence and previous plans intact.
- [x] Root: independently review specification compliance then code quality with Luna reviewers. Fix findings and obtain approval.
- [x] Root: run core and optional RBS suites plus signature validation on Ruby 3.3.6, 3.4.7 and 4.0.1; default locked rake/lint and packaging. Run the new example using a built/installed gem and export skills; exercise the RBS-only domain workflow using the updated guidance.
- [x] Root: record concise final results and exact verification evidence; commit with Lore trailers on the feature branch. No merge or publication.

Commands use prepared scratch bundles, leaving project lockfiles unchanged:

```sh
env -i PATH=/Users/luciang/.rubies/ruby-4.0.1/bin:/usr/bin:/bin BUNDLE_GEMFILE=/private/tmp/specproof-rbs-strings-40/Gemfile BUNDLE_PATH=/private/tmp/specproof-selection-40/vendor/bundle /Users/luciang/.rubies/ruby-4.0.1/bin/bundle exec ruby bin/test test/rbs/source_test.rb
```

For the default development bundle use suffix `40-default-locked` for both
scratch Gemfile and existing `specproof-selection` bundle path, then `bundle
exec rake`. Other matrix runtimes use keys `33`/`34` and installed Ruby
versions `3.3.6`/`3.4.7`. Temporary utility scripts are Ruby standard library
only. Agents own disjoint files, adapt to others' changes, and do not commit
or revert others' edits.
