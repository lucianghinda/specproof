# Method target support: verification

String declarations and Ruby method objects now share canonical target names:
`Owner#method` for instance methods and `Owner.method` for class/module
singleton methods. Equivalent declarations have matching contract digests
and obligation IDs. Strings remain usable without loading application code;
method objects require loaded code and a current public Ruby definition.

The [runnable example](../examples/method_targets/README.md) produces eight
matching target/obligation identities from its string and method-object forms.
The input contract does not capture return values, execute the target during
normalization, or promise editor navigation. Collection resolves the canonical
name when it starts, rather than pinning the declaration's method object.

Luna subagents implemented target normalization, singleton collection, RBS
projection, documentation and agent skills. Independent specification and
quality reviews found no remaining blockers.

## Verification

On each of CRuby 3.3.6, 3.4.7 and 4.0.1:

| Suite | Tests | Assertions |
| --- | ---: | ---: |
| Core | 324 | 1,666 |
| Optional RBS | 60 | 537 |

All passed without failures, errors or skips. RBS signature validation,
RuboCop (151 files), syntax, packaged skill checks and gem building passed.
Tests cover equivalent declarations, separate same-named instance/singleton
targets, optional and excluded arguments, aliases called through the selected
definition, stale method objects, invalid owners, source-aware errors,
redefinition, constant binding changes and RBS singleton declarations.

## Real-project continuation

The earlier [pilot](real-project-pilot.md) rejected
`Agent::SessionContext::SemanticCategories.lookup(identifier)` because class
methods were unsupported. A new Luna exercise used the unchanged method and
the candidate's unchanged `SummaryParserTest` file with both target forms.

Both declarations passed check and plan, with the same twelve obligations and
digest `2446066802513c19caee861f0c2d7b607559fcf72e0f3359fa862044292c8ea2`.
The domain was explicitly scoped to six strings and six symbols from the
existing catalog assertion, not arbitrary string inputs.

The normal test helper could not load the unrelated `agent_sessions`
dependency from the prepared bundle. A scratch-only helper loaded the parser's
local supporting classes without wrapping or changing the selected method.
Each form then passed the same twelve tests and 110 assertions. Both reports
were completed and intact, with identical scope and hit projections: seven
exercised inputs, five missing and zero unknown. No dependencies were installed
and no application files were edited. This demonstrates the focused test file,
not the application's full suite under its normal helper.

The missing symbols were `:constraint`, `:decision`, `:next_action`,
`:open_question` and `:term`. The agent left them untested rather than deriving
expected lookup results from implementation code. This exercise followed the
updated source-checkout skills; it was not an installed-gem evaluation.

## Limits

Direct public instance methods require a named class; singleton methods may
belong to a named class or module. Arbitrary bound instance methods, anonymous
owners, aliased declarations, inherited singleton declarations and native
methods are rejected. An UnboundMethod identifies its defining class, including
when obtained by reflecting through a subclass. RBS selection still uses
explicit string targets and its existing supported type subset.
