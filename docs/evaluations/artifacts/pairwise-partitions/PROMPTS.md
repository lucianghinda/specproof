# Agent exercise requests

Two fresh Luna agents received separate scratch copies of the age-by-country
fixture and access to the installed feature gem. This comparison was run after
implementation; it was not a test-first skills experiment.

The common task was to read the supplied `specproof-specify` and
`specproof-test-gaps` skills and references, requirements, specification, and
existing tests; measure pairs of declared age categories crossed with countries
for the initial tests; use suggestions to add the missing requirement-backed
assertion; then rerun. Agents could add a runner and new test, but had to
preserve the specification, production method, and existing assertions. They
were told not to substitute marginal boundary coverage, invent undocumented
flags, or invent expected outputs. If the supplied guidance could not support
category-pair measurement, they were to record the exact blocker.

Both agents were restricted to their fixture, supplied skills/references, and
installed CLI. Repository source, installed library source, other installed
documentation, and the other exercise directory were excluded. They were asked
to retain raw reports/logs and a result with commands, counts, criterion, and
limitations. No dependency changes were allowed; utility scripts used Ruby's
standard library.

The baseline agent received the skill files from commit `21959ba` and worked
in `/private/tmp/specproof-partitions-agent-check/baseline`. The guided agent
received the feature gem's packaged skills in the sibling `guided` directory.
The guided request additionally asked it to alter category bounds in a copy of
the initial coverage report, verify suggestion rejection, and preserve the
original report.

Commands used this isolated environment:

```text
PATH=/Users/luciang/.rubies/ruby-4.0.1/bin:/usr/bin:/bin
GEM_HOME=/private/tmp/specproof-partitions-installed
GEM_PATH=/private/tmp/specproof-partitions-installed:/private/tmp/specproof-selection-40/vendor/bundle/ruby/4.0.0
MT_NO_PLUGINS=1
Ruby: /Users/luciang/.rubies/ruby-4.0.1/bin/ruby
CLI: /private/tmp/specproof-partitions-installed/gems/specproof-0.1.0/exe/specproof
```

Coordinator follow-up corrected a fixture interaction: the guided runner first
used `ADD_MISSING_CATEGORY`, which also enabled an existing dormant reference
test. The agent was instructed to use a distinct flag for its added test, leave
the fixture flag unset, rerun, and disclose the correction. After a final
criterion-string ownership fix, the gem was rebuilt and the guided agent was
asked to refresh all commands and evidence. The coordinator also reran the
baseline check and finite plan against that final installed gem.
