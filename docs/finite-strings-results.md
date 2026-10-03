# Finite string values

Implemented on `implement/finite-strings`, based on `main` at `f63dcaa`.
Core, tests, documentation and skills are committed as `8195cae`.

```ruby
SpecProof.define "PStoreLogger#save" do
  input :file_id, values: [nil, 1, "user_123"]
  exclude_input :data, reason: "Payload contents are outside these file-ID scenarios"
end
```

Finite domains and partitions now accept exact valid UTF-8 or US-ASCII String
values, including empty strings and Unicode text. US-ASCII is stored as UTF-8;
there is no trimming, case folding or Unicode normalization. Same-spelling
strings and symbols are distinct. Declaration values and runtime observations
are copied and frozen without changing application-owned values. Collection
uses the value at method entry even when the method later mutates it.

JSON adds the typed value `{ "kind": "string", "value": "user_123" }` under
schema 1 and the existing `input-basics-v1` criterion. Existing nonstring IDs
and digests remain unchanged. Consumers must handle the new value kind.

## Changes and simplifications

- `lib/specproof/domains.rb` centralizes supported-value validation and text
  snapshots. The existing finite-domain representation, checker and planner
  handle strings without a parallel string-domain hierarchy.
- Model, coverage, collector, report and source-neutral type constraints reuse
  those rules; `sig/specproof.rbs` describes the expanded public value union.
- Focused tests cover encodings, mutation, mixed symbol/string values,
  partitions, typed reports, runtime integrity and legacy identities.
- README, report documentation and both packaged agent skills explain exact
  scenario scope and preserve independent assertion requirements.

No new dependency, CLI option, adequacy criterion or RBS extraction feature was
added. RBS String types and string literals remain unsupported atomically,
including mixed unions.

## Verification

Each CRuby version (3.3.6, 3.4.7, 4.0.1) passes **178 core tests / 885
assertions** and **46 optional RBS tests / 433 assertions**, with zero failures,
errors or skips. RBS signatures validate on all three. The locked default
Ruby 4 bundle passes `rake`, including RuboCop's 98-file check. `bin/check`
passes syntax, package and skill checks (2 tests / 76 assertions).

Independent Luna specification and quality reviews approved the change.
[Matrix records](pilots/finite-strings/matrix/) retain actual commands, outputs,
statuses and library hashes. [Agent exercises](evaluations/finite-strings-skills.md)
retain an old-guidance baseline and actual installed-package application runs.

## Real-project value

The [PStoreLogger pilot](pilots/finite-strings/README.md) preserves its original
five source/test files. Its unchanged suite passes 7 tests / 23 assertions but
exercises only 2/3 declared values: `"user_123"` is missing. Strict missing mode
correctly exits 1 while the report preserves `tests_passed: true`.

A separate test uses its README's custom-file-ID and collision rules to check
`user_123.pstore`, `user_123_1.pstore`, and the stored payloads. The resulting
suite passes 8 tests / 27 assertions and exercises 3/3 with intact collection.
The original application and tests are unchanged.
An independent evidence review confirmed the five source-file hashes, all 17
runtime library hashes, matching scope/digest/obligation IDs, and distinct
baseline/final run IDs.

## Limits

This covers explicitly enumerated scenarios, not the entire String domain or
whole-method correctness. Other encodings, invalid text, String subclasses,
patterns, length constraints, RBS strings, outputs and interaction coverage are
outside this milestone. Outside-domain witness count remains bounded, but a
retained string witness contains the full text, so there is no byte-size bound.
The agent exercises are small guided tasks, not a general reliability estimate.
