# RBS agent workflow evaluation

Six fresh native subagents were requested with `gpt-6-luna`, high reasoning, and no inherited conversation. Each received an isolated workspace, an explicit target and task, and instructions to load the exported SpecProof skill and its reference. A coordinator-provided Ruby command recorder selected the installed gem and optional dependencies. These are guided workflow observations, not automatic skill discovery tests or a general agent reliability estimate.

[Coordinator request metadata](artifacts/rbs-v0.1/coordinator-requests.json)
records those routing settings and task names. This is a coordinator record of
the successful requests, not independent server attestation of model identity.

Final quality review found that an extra DSL input absent from a selected RBS
signature could be planned offline. After fixing that boundary in `c0d32ad`,
the gem was rebuilt and all six scenarios were repeated with fresh actors.
This record describes the final repeat. The [initial pass](artifacts/rbs-v0.1-pre-binding-check)
remains separate evidence; its outcomes are not pooled into a success rate.

The skills were exported from a real built and installed SpecProof 0.1.0 gem outside the checkout. The package had no runtime dependencies. RBS 4.2.0 and Minitest 5.26.2 came from the published packages in an isolated Ruby 4.0.1 bundle. [Package/export metadata](artifacts/rbs-v0.1/installed-package.json), [loaded package paths and hashes](artifacts/rbs-v0.1/runtime-probe.json), and the [root evidence audit](artifacts/rbs-v0.1/root-audit.json) record the actual environment. All four exported skill files match the current source bytes; all 17 installed library files match this implementation.

## Observed scenarios

| Scenario | Observed result | Retained record |
| --- | --- | --- |
| Finite RBS input | Clean check and plan; two boolean candidates, no duplicate DSL domain | [01-finite](artifacts/rbs-v0.1/01-finite/RESULT.md) |
| Missing behavioral refinement | Added only age bounds and exhaustive/disjoint partitions; consent stayed RBS-derived; nine marginal obligations | [02-refinement](artifacts/rbs-v0.1/02-refinement/RESULT.md) |
| Contradictory refinement | Reported `type_domain_conflict` with `:unexpected` and both sources; left declarations unchanged and did not plan through the finding | [03-conflict](artifacts/rbs-v0.1/03-conflict/RESULT.md) |
| Unsupported union | Reported `unsupported_rbs_type` for the String arm; no partial boolean plan or narrowing workaround | [04-unsupported](artifacts/rbs-v0.1/04-unsupported/RESULT.md) |
| Stale report | Rejected the prior passing 9/9 report despite identical current input digest and IDs; fresh run failed at age 18 and observed 5/9 | [05-stale](artifacts/rbs-v0.1/05-stale/RESULT.md) |
| Justified boundary gap | Added a requirement-backed age-18 assertion, captured RED before the implementation edit, then changed `>` to `>=`; fresh final run passed with 9/9 | [06-boundary](artifacts/rbs-v0.1/06-boundary/RESULT.md) |

For the last two scenarios, the independent supplied rule is: eligible exactly when age is at least 18 and consent is true; nil and false deny eligibility. RBS supplies input types only. The missing age-18 obligation is `f34bb1fa38998396c7ddf02a20ba326da6c30131d696dabee7e7f6acff06daa8`.

The boundary actor inserted its assertion within the existing test. Its RED failure stopped the remaining assertions, so that run observed **5/9**, while preserving those assertions for the passing final run. Its baseline was **8/9**, and its final was **9/9** with eight assertions. All three retained the same nine obligation IDs and digest, with distinct run IDs. This differs from the shipped example, whose separate boundary test allows the baseline test to finish and demonstrates **9/9 with failing tests**. Both records retain the actual observations.

The stale fixture deliberately produced a passing report before changing `>= 18` to `> 18`, without changing its input contract or tests. The actor was instructed to inspect and rerun, without repairing the implementation. Its fresh failure establishes why matching input digests cannot attest implementation freshness or correctness. The four unobserved obligations follow from the failing assertion stopping that test.

## Evidence and reproduction

Each scenario directory contains the actor's actual `RESULT.md`, a `workspace.tar.gz`, and a file-hash manifest. The archive retains the supplied rules, RBS/DSL, exported skills, final edited files, reports, and JSON command records with argv, cwd, timestamps, stdout, stderr, environment, and exit status. [Initial fixtures](artifacts/rbs-v0.1/initial-fixtures.tar.gz) preserve the pre-evaluation inputs, including the original boundary implementation. Historical evaluation archives were not rewritten.

The command recorder and setup/audit scripts are retained as `.rb.txt` files in [the artifact directory](artifacts/rbs-v0.1). Absolute paths in command records describe the original run. To rerun tools, extract a workspace into a scratch directory and use a normal Ruby environment containing this SpecProof implementation, RBS 4.2.0, and Minitest 5.26.2. Check and plan with its recorded explicit DSL paths, `--rbs sig/project.rbs`, and selected `--target`. Runtime fixtures use `REPORT_NAME=new-report.json ruby run.rb`. Reconstruct the original boundary workspace from the initial-fixture archive for a new RED/fix sequence; the final boundary workspace already contains the fix. Do not overwrite retained reports when reproducing.

The audit checks CLI exit codes and diagnostics, preserved signatures/requirements, imported consent provenance, runtime IDs/digests/scope, fresh UUIDs, RED/green results, unchanged stale-case code/tests, and exact skill/library hashes. A separate review audits these records. Neither the root audit nor six guided tasks establish general agent reliability, client skill discovery, full-project coverage, or arbitrary Ruby behavior conformance.

The [independent final audit](../pilots/rbs-v0.1/independent-final-audit.json)
also checked actual tar members against their manifests, both evaluation
passes, the final installed package, and unchanged historical archives.
