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
2. If an input's allowed domain or partition intent is missing, ask a focused
   question before declaring it. If requirements and implementation disagree,
   report the mismatch with source locations; do not rewrite the requirement or
   implementation to make the check green without direction.
3. Add a small trusted Ruby specification file. Declare only supported input
   domains and partitions. Do not declare return values or other output
   behavior: SpecProof's contract describes inputs only.
4. Mark a partition family `exhaustive: true` only when the requirements say it
   covers the entire input domain. Mark it `disjoint: true` only when the
   requirements say the partitions cannot overlap. Leave either promise out
   when the requirement is unknown, then ask about the missing policy rather
   than choosing a boundary.
5. Run `specproof check PATH --format json` and inspect the structured
   `findings`, `errors`, and `contract_digest`. Resolve or report every finding.
   After the declared promises check clean, run
   `specproof plan PATH --format json`. Check that the criterion, candidate
   values, reasons, IDs, and source locations match the requested contract.
6. Report the contract digest, candidate values, and declaration source
   locations. Explain any unresolved question. Describe the plan as boundary
   candidates, not as a complete or proven test suite.

Use the project's established command environment. For a Bundler-managed
project, prefix commands with `bundle exec`. For JSON output and schema details,
read [the bundled command and report reference](references/usage.md).

## Supported declarations

SpecProof accepts bounded integer ranges and finite arrays of `nil`, booleans,
integers, or symbols. Integer range endpoints are inclusive unless Ruby's
exclusive range form (`...`) is used. A specification declares a target and
one or more named inputs:

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
or keyword inputs, including optional parameters. Declare every parameter.
Domains describe effective values at method entry, after Ruby applies defaults;
they do not assert whether the caller omitted an argument. Do not evaluate or
guess default expressions while authoring the domain.
Load specification files only from trusted project sources;
they are executable Ruby. SpecProof does not load the application class while
checking or planning.
