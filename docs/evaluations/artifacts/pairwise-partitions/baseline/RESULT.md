# Baseline category-pair exercise

The existing baseline test calls cover **3 of the 4** pairs of declared age category × country:

| Age category | Country | Baseline evidence |
| --- | --- | --- |
| minor (`16`) | `ro` | present |
| minor | `de` | missing |
| adult (`30`) | `ro` | present |
| adult (`30`) | `de` | present |

The age categories come from `specification.rb` (`minor: 0...18`, `adult: 18..120`); countries are `ro` and `de`. This is a direct mapping of the three calls in `BASELINE_CASES`, not a SpecProof pairwise report.

SpecProof 0.1.0 accepted the specification in `check` with no errors or findings and digest `ce20c25f686bcb8e62d8979816858f2937dc6cee570898107ef416093687a79c`. The required pairwise plan (`--criterion pairwise-finite-v1`) was rejected with `finite_combinations_required`: `combinations input :age must have finite values`, sourced to `specification.rb:6`. The declared age input is a range divided into two partitions; the installed pairwise planner does not treat those partitions as finite combination values.

The supplied guidance requires pairwise group inputs to have finite analyzed domains, and `suggest` requires a fresh, completed, intact pairwise coverage report matching a successful pairwise plan. Since no allowed pairwise plan can be produced from the unchanged contract, no valid pairwise baseline report or suggestion can be generated. I did not replace categories with marginal boundary candidates or guess representative ages. Consequently, no missing assertion was added and no Minitest run was performed.

The exact commands and raw JSON outputs are preserved in `logs/commands.log` and `rawreports/`. No specification, production file, or existing assertion was changed.
