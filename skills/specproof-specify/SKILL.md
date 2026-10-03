---
name: specproof-specify
description: Creates and reviews explicit SpecProof input specifications for Ruby methods. Use when a task asks to define input domains or partitions, check gaps and overlaps, or plan boundary candidates with SpecProof.
---

# Specify Ruby method inputs with SpecProof

Create a bounded input contract from stated requirements and verify its
partitions with the project's SpecProof command line. Keep the contract tied
to independent requirements and the implementation source. Do not infer an
intended policy from a method's current behavior.

## Workflow

1. Read the user request, relevant product requirements, the target Ruby method,
   and its existing tests. Identify the exact `Class#instance_method` target and
   each requested input. Distinguish explicit requirements from assumptions.
   When RBS is supplied, inspect explicitly selected RBS target signatures
   first. Reuse supported finite input types directly;
   add a DSL declaration only for a behavioral range or partition the type
   cannot express. Do not search for other signatures or duplicate finite
   values in the DSL.
2. If an input's allowed domain or partition intent is missing, ask a focused
   question before declaring it. If requirements and implementation disagree,
   report the mismatch with source locations; do not rewrite the requirement or
   implementation to make the check green without direction.
3. Add a small trusted Ruby specification file. By default, every named
   runtime parameter must have an analyzed `input` declaration. If requirements
   intentionally limit this task to only some inputs, declare each remaining
   named parameter with `exclude_input :name, reason: "..."`; exclusions must
   be explicit, named, and justified by scope. There is no wildcard or
   implicit exclusion, and at least one input must remain analyzed. An exclusion
   does not add obligations or excuse an unsupported selected input. For a
   selected RBS target, finite supported inputs can be imported without
   duplicate DSL values; DSL exclusions can account for deliberately
   out-of-scope or unsupported type-only parameters. Unsupported selected union
   types remain atomic failures. Do not infer a finite range for unrestricted
   `Integer`, guess from a name or implementation, or write partial obligations
   for unsupported input types or union members. Stop and report the selected
   target/input and source location whenever a type is unsupported or needs a
   bounded refinement. Finite DSL strings are available only when a fresh
   `check` and `plan` from the installed build
   accept and report the string kind; a `0.1.x` version alone does not establish
   support. If a required string value is unsupported, preserve it in the
   reported request and stop. Do not substitute a same-spelling symbol, drop
   the string, or report an invalid/partial plan as valid.
4. Mark a partition family `exhaustive: true` only when the requirements say it
   covers the entire input domain. Mark it `disjoint: true` only when the
   requirements say the partitions cannot overlap. Leave either promise out
   when the requirement is unknown, then ask about the missing policy rather
   than choosing a boundary.
5. Run `specproof check PATH --format json` and inspect the structured
   `findings`, `errors`, and `contract_digest`. For RBS, pass each selected file
   with `--rbs FILE` and each target with `--target 'Class#method'`; a target
   selector is required and imports only that target. Unsupported union arms
   are atomic failures: do not guess, drop an arm, or turn the remainder into a
   partial contract. Resolve or report every finding before planning. After
   the check is clean, run `specproof plan` with the same source and target
   options. Compare the criterion, candidate values, reasons, IDs, and source
   locations with the stated contract. Optional parameters and nullable types
   are distinct: optionality permits omission, while `T?` permits an effective
   `nil` value after Ruby applies defaults.
6. Report the contract digest, candidate values, and declaration source
   locations. If inputs are excluded, report each name and reason. Explain any
   unresolved question. Describe the plan as boundary candidates, not as a
   complete or proven test suite.

Use the project's established command environment. For a Bundler-managed
project, prefix commands with `bundle exec`. For JSON output and schema details,
read [the bundled command and report reference](references/usage.md).

## Supported declarations

SpecProof accepts bounded integer ranges and finite arrays of `nil`, booleans,
integers, and symbols. Builds with finite-string support also accept explicitly
listed text values. Integer range endpoints are inclusive unless Ruby's
exclusive range form (`...`) is used. For example, `values: [nil, 1,
"user_123"]` describes those three exact candidates; it is a finite scenario,
not the full String domain. String and symbol values with identical spelling
are distinct. Strings must be exact `String` instances encoded as valid UTF-8
or US-ASCII; US-ASCII is canonicalized to UTF-8. Empty, whitespace, Unicode,
and embedded-NUL strings are valid. Invalid byte sequences, other encodings,
and String subclasses are rejected. No trimming, case folding, or Unicode
normalization occurs. A specification declares a target and one or more named
inputs. The existing partition membership, gap, overlap, exhaustive, and
disjoint checks apply to explicitly enumerated string values; strings are not
coerced to symbols or other scalar types:

```ruby
require "specproof"

SpecProof.define "Registration#adult?" do
  input :age, range: 0..120, exhaustive: true, disjoint: true do
    partition :minor, range: 0...18
    partition :adult, range: 18..120
  end
end
```

Keep the declared method signature aligned with the real named positional
or keyword inputs, including optional parameters. By default, declare every
parameter with `input`. To scope a contract to only some parameters, account
for every other name with an explicit `exclude_input` and a reason:

```ruby
SpecProof.define "DeliveryPolicy#accept?" do
  input :expedited, values: [false, true]
  exclude_input :payload, reason: "Payload content is outside this option coverage"
end
```

No input may disappear through a wildcard or omission, and a contract must
analyze at least one input. Domains describe effective values at method entry,
after Ruby applies defaults; they do not assert whether the caller omitted an
argument. Excluded values are not read by runtime collection; selected
non-primitive values still make collection incomplete. Do not evaluate or guess
default expressions while authoring the domain. SpecProof copies and freezes
owned declaration and entry-observation snapshots, so later application
mutation cannot change matching and application-owned strings are not frozen.
Direct Coverage observation also owns retained string witnesses; an
outside-domain string witness is full-sized even though witness count is
bounded.

## Explicit RBS inputs

For an explicitly selected RBS target, `bool`, `nil`, supported scalar
literals, and finite unions provide finite input candidates without a duplicate
DSL declaration. A resolved built-in `::Integer` remains unbounded and requires
an explicit finite range or values before SpecProof can produce candidates.
Existing DSL range and partition declarations are behavioral refinements, not
claims inferred from RBS. Check that every declared value is admitted by the
imported type; a contradiction is a conflict to resolve, not an intersection
to silently accept. An explicit DSL exclusion can scope out an otherwise
unsupported type-only input while finite selected inputs remain imported; do
not exclude a member of an unsupported selected union to make that union appear
supported. Return types do not supply expected results, behavior
rules, or an output oracle. The report digest fingerprints normalized input
domains, partition policies, and sorted excluded input names, not exclusion
reasons/source locations, all declaration text, a full RBS signature, or
implementation correctness. Existing no-exclusion digests and obligation IDs
remain stable. Run fresh checks and reports after any input source changes.
RBS string types and string literals remain unsupported, including inside
unions, and fail atomically. DSL finite-string support does not widen the RBS
adapter.
Load specification files only from trusted project sources;
they are executable Ruby. SpecProof does not load the application class while
checking or planning.
