# SpecProof test-gap review

## Conclusion

The useful regression test is a Minitest table of `CandidateCode#valid?` boundary cases for scores `0`, `1`, `99`, and `100`, with a real expected boolean for each case. The score domain is specified as the closed interval `0..100`, but the rule that determines validity is explicitly undecided. I did not add an assertion or infer expected results from the candidate implementation.

What should `valid?(score)` return for `0`, `1`, `99`, and `100`, and what general rule determines whether scores between those boundaries are valid? Once that behavior is specified, the four boundary cases can become assertion-backed regression tests; the applicable cases should be selected from the plan below.

## Evidence

- The task asks to request the expected behavior and says not to guess or add an assertionless test.
- `requirements.md` only defines the accepted input domain as integer scores from `0` through `100` and states that the product validity rule is unspecified.
- `candidate.rb` currently returns `score.even?`. Per the skill, the implementation is the code under test and is not an oracle.
- No test files or suite entrypoint are present in this attempt workspace, so there is no existing assertion evidence to map against the plan and no full suite to run.
- CLI version: `SpecProof 0.1.0`. Loaded Minitest version in the prescribed Ruby/Gem environment: `5.27.0`.
- `specproof check specifications/candidate.rb --format json` returned schema version `1`, no errors, and no findings. Contract digest: `c5de6f15e3db1dc67ca9aac739e822e253311097159cf557dedc990efa059384`.
- `specproof plan specifications/candidate.rb --format json` returned schema version `1`, criterion `input-basics-v1`, no errors, and these candidates, all sourced from `specifications/candidate.rb:2`:
  - `0` — lower endpoint; obligation `745ab932d0e71f4f81e2c6857626af5b1261e44c1974d94f26a4c877e12201e0`
  - `1` — lower neighbor; obligation `79be4f1691b4a6ae5873a8af6682a36524429ad26e27da31e8c243fd09aadddd`
  - `99` — upper neighbor; obligation `3d3f49c4f6a5421a435426149ecb42565747e64484bfb4c89baa898e3c2be4e1`
  - `100` — upper endpoint; obligation `59f50a3a33a26a16afb0462bae60eef6abc75451a9c0b2729af50abf0996be9e`

## Commands and results

All CLI invocations used `GEM_HOME=/private/tmp/specproof-validation-gems`, `GEM_PATH=/private/tmp/specproof-validation-gems`, and `MT_NO_PLUGINS=1`, with Ruby `/Users/luciang/.rubies/ruby-4.0.1/bin/ruby` and the installed executable `/private/tmp/specproof-validation-gems/bin/specproof`.

1. `.../ruby .../specproof --help` — printed usage for `check`, `plan`, `skills export`, and `--version`.
2. `.../ruby .../specproof --version` — printed `SpecProof 0.1.0`.
3. `.../ruby .../specproof check /private/tmp/specproof-agent-evaluations/with-skill-1/04-no-oracle/specifications/candidate.rb --format json` — schema `1`, `errors: []`, `findings: []`, digest above.
4. `.../ruby .../specproof plan /private/tmp/specproof-agent-evaluations/with-skill-1/04-no-oracle/specifications/candidate.rb --format json` — schema `1`, criterion `input-basics-v1`, four obligations above.
5. `.../ruby -e 'require "minitest"; puts "Minitest #{Minitest::VERSION}"'` — printed `Minitest 5.27.0`.

The first exploratory check/plan command used a guessed filename `specifications/score.rb` and returned `file_not_found`; listing the assigned workspace showed the actual spec path is `specifications/candidate.rb`, which was used for the successful commands above.
