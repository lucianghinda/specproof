# Optional scalar arguments

Approved continuation after the real-project pilot: observe effective Ruby-bound optional positional and keyword values, then repeat the PStoreLogger primitive-scenario pilot.

## Contract

- Support named required/optional positional and keyword parameters. Every parameter must still have an input declaration.
- Capture effective values at Ruby method entry. Do not inspect or execute default expressions, infer omission, add omission-specific obligations, or change existing IDs/criterion.
- Preserve rejection of rest, keyword-rest, forwarding, explicit blocks, class-method targets, inherited/aliased declarations, and non-primitive observed tuples.
- A default that raises before method entry supplies no entry observation. Ruby's original exception and side effects remain unchanged.
- A non-primitive effective value keeps collection incomplete; a primitive value outside its declared domain contributes no valid tuple hits.
- Reports explicitly identify effective bound values and unavailable argument-presence evidence. This is additive metadata under schema 1.

## Implementation and acceptance

1. Prove TracePoint default timing and side effects with failing collector tests before widening the parameter allowlist. Cover mixed signatures, dependent defaults, omitted/explicit equal values, raising defaults, non-primitive defaults, and unsupported signatures.
2. Add optional-argument Minitest subprocess integration: stable shared obligations, repeated nil hits from omission and explicit nil, preserved failure semantics, whole-tuple validation, and incomplete evidence on observation failure. Document semantics in the report contract, README, and agent reference.
3. Run all required checks on Ruby 3.3/3.4/4.0 with published Minitest 5.26.2 and independent specification/quality review.
4. Repeat PStoreLogger on a copied source snapshot using Ruby 3.4's standard-library PStore. Preserve existing tests and production source, export skills, and ground added persistence assertions in project and PStore contracts.

The existing PStoreLogger tests pass Hash payloads. Such calls remain unsupported by scalar collection and must not be silently discarded. Retain an instrumented full-suite run showing that limitation, plus a clearly filtered fresh primitive-scenario run if the declared subset can be exercised completely. A full uninstrumented suite must still pass after adding tests; filtered coverage is never whole-suite coverage.

## Deferred

No structured-object domains, strings, arbitrary argument serialization, default-expression static analysis, omission coverage, class-method collection, or replay in this slice.
