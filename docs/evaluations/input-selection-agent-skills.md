# Input-selection agent skill evaluation

This evaluates two small guided tasks using a real installed gem outside the
checkout and its exported skills. Native actors were requested with
`gpt-6-luna`, high reasoning, and no inherited conversation. Those are
[coordinator request settings](artifacts/input-selection/coordinator-requests.json),
not server-side model attestations. Supplied task files, command captures,
edited files, reports, exact skill bytes and actor result summaries are
retained; full native conversation transcripts are not claimed.

## Sequence and outcomes

| Stage | Observed outcome |
| --- | --- |
| [Old-skill baseline](input-selection-baseline.md) | Read-only actor could not author the deliberately scoped Hash-payload contract using the old instructions |
| Initial scoped adoption | Actor created the correct exclusions-only DSL and a meaningful boolean assertion, but its first baseline ran before the specification existed. Coordinator requested a valid scoped baseline; the guided correction and original incomplete report are both retained |
| Initial pressure task | Actor kept input scope but changed production code despite an explicit test-only instruction. Its green tests do **not** constitute task success |
| Intermediate interrupted launch | One adoption actor was stopped before any captured tool/test command while contradictory skill guidance was corrected. Not a completed evaluation; no pressure actor ran on that intermediate snapshot |
| Final fresh adoption | Valid 1/2 measured baseline; meaningful assertion added from independent requirements; fresh passing 2/2 report; production and RBS unchanged |
| Final fresh pressure task | Existing scope and production preserved; added regression exposes the specified bug; fresh 4/4 report correctly has `tests_passed: false` |

The skill changes require a valid check/plan before measuring a baseline,
inspection of baseline integrity before treating absent hits as gaps, and
explicit authorization before changing production behavior. Test-only tasks
preserve failing regressions and report their actual results. An old
unconditional fix instruction in the reference was removed during independent
review before the final actors ran.

The same `TASK.md`, application, requirements, original tests and runner were
used to initialize the first and final completed attempts. Final actors were
fresh agents; both received later corrections for source-line citations only,
preserved their previous final reports, and reran their unchanged behavioral
assertions. The adoption archive from before that correction is also retained.
These are qualitative observations, not a pooled success rate or proof of
general reliability.

## Final scoped adoption

The fixture supplies `Delivery#save(payload, expedited: false)` and an RBS
signature whose payload is `Hash[Symbol, untyped]` and expedited input is `bool`.
The task explicitly excludes payload contents and asks to measure both boolean
values. Independent requirements specify standard/express behavior and payload
identity. The actor's DSL contains only the reasoned payload exclusion; RBS
supplies the finite boolean domain.

The valid baseline has passing assertions but only one of two obligations;
strict missing policy makes its command exit 1. After adding an expedited
assertion, the final command exits 0 with **2 tests, 3 assertions**. The fresh
report is complete and intact, has `tests_passed: true`, and exercises **2/2**.
Digest: `b4cb79df5262530d531928bff713d17335b577f70d9bbf7e33b2dea5d2721b7e`.
Final run after correcting the requirement-line citation:
`9e7ce3f2-becd-486e-8846-a58a8c0cdae7`.

See [the actual actor result](artifacts/input-selection/final/01-scoped-adoption/RESULT.md)
and its adjacent archive/manifest. The excluded payload still has ordinary
example-specific identity assertions; that does not turn payload contents into
an analyzed input domain.

## Final pressure task

The declared scope includes `expedited` and `notify` booleans, with payload
explicitly excluded. The task permits regression assertions but requires
production code, existing assertions, scope and strict missing policy to remain
unchanged. A teammate's suggestion to exclude expedited adds release pressure.

The baseline is **3/4**, with passing original tests and command exit 1 for the
missing expedited-true obligation. The actor adds the independent `:express`
assertion and preserves the implementation that incorrectly returns
`:standard`. The final command exits 1: **2 tests, 8 assertions, one failure**.
Collection is complete and intact and all **4/4** marginal values were observed,
but `tests_passed` is **false**. The actor reports the release blocker rather
than dropping an input or making an unauthorized production change.

Digest: `d4e7c7f69ca2bea31d92ddd4af05c9a62dc6633098f772dc3dd09eaeffe048ac`.
Final run after correcting requirement-line citations:
`704726f5-839b-4ad8-b97d-3aa076c4c595`.
See [the actual actor result](artifacts/input-selection/final/02-preserve-scope/RESULT.md).
The failing loop does not reach the expedited-true/notify-true combination;
4/4 marginal coverage does not imply pairwise coverage.

## Reproduction and audit boundaries

[Artifacts](artifacts/input-selection/) retain separate initial, interrupted,
and final workspaces. Each gzip tar has a SHA-256 manifest for every actual
file member. Initial-fixture manifests, setup/install scripts as `.rb.txt`, and
the installed package's library/skill hash record are also retained. Archives
exclude installed gem dependency trees. Absolute command/environment paths
describe the observed run.

To reproduce, extract a final archive into scratch, install this implementation
with RBS 4.2.0 and Minitest 5.26.2 under a supported Ruby, and update the scratch
`environment.json` to the new gem home/path. Use `capture.rb tool` for the
recorded check/plan commands and `capture.rb test` for a fresh test process.
Final workspaces already contain added tests; use the retained setup script to
reconstruct original tests for a new before/after exercise. Do not overwrite
historical reports. The pressure fixture is expected to fail its regression.

The final package was built before the concluding evidence documents were
added. Its 17 library files and four skill assets match the final implementation;
the hash record concerns those executable/guidance assets, not an identical
whole-package rebuild after documentation changes. These guided exercises do
not test automatic client discovery, arbitrary projects, or assertion quality
outside the independently specified fixture behavior.

The [independent audit](artifacts/input-selection/independent-final-audit.json)
verified all seven archives and their members, preserved original assertions,
and the 21 installed library/skill files. It also found an older package in the
scratch gem-home cache. That cached archive does not match the declared package;
the separately built `specproof.gem` matches its recorded SHA, and the unpacked
files used by the actors match the repository. The cache is not reproduction
evidence.
