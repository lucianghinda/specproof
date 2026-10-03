# All-in-Ruby pairwise baseline pilot

Captured: 2026-10-03T15:46:20Z
Source revision: `bbe9921470cbf80ae01ae4fbb2de50a62187ba9e`
Scratch copy: `/private/tmp/specproof-suggestions-pilot`
Source working tree had pre-existing edits to `Gemfile` and `test/installer_test.rb`; tests were copied from clean HEAD. Production files in the copy match HEAD. Original working-tree file hashes are recorded in `baseline-manifest.json`; post-pilot hashes are recorded in `post-pilot-source-hashes.json`.

## Declaration

Target `AllInRuby::Installer#install` has runtime values `scope: "local" | "global"`, `dry_run: false | true`, and `backup: false | true`. The source signature is `install(agents:, scope:, dry_run: false, backup: true)`. Calls bind `scope` as a String; the earlier Symbol declaration produced 29 invalid tuples and 0 hits, so it is retained only as `coverage-symbol-mismatch.json` diagnostic evidence. The final specification uses Strings and matches the actual method values.

`agents` is explicitly excluded with reason: “Agent selection is a collection parameter; suggestions supply the requested agents separately.” It is an Array and outside this finite primitive assignment group; every proposed test must still provide `agents:`. Group inputs cover every other named parameter. The pilot author selects `all_allowed: true` based on the documented separate scope and option flags (`README.md:127-138`), the explicit combined scope example (`README.md:138`), and distinct documented `--dry-run` / `--no-backup` behavior (`README.md:79, 83-90`). This is a requirement-backed pilot declaration; the flag availability alone does not mechanically prove every joint behavior. Scope plus the two Boolean flags yield 12 feasible pair rows and no excluded pairs.

## Actual baseline

Command: `specproof plan spec/installer_spec.rb --criterion pairwise-finite-v1 --format json` (exit 0).

Command: `bundle exec ruby -Ilib:test run_baseline_coverage.rb` (exit 0); Minitest assertions passed: 32 runs, 104 assertions, 0 failures, 0 errors, 0 skips. No Minitest filter/exclude args were supplied.

Run ID: `5ba2c09e-a511-4cc9-a093-5df94093d450`; completion `completed`; integrity `true`; tests_passed `true`; contract digest matched plan: `true`. Coverage was 9/12 exercised; 3 missing; 0 unknown; 0 excluded pairs.

Missing pairs:
- `backup=false × dry_run=true`
- `backup=false × scope="global"`
- `dry_run=true × scope="global"`

The one full assignment `scope="global", dry_run=true, backup=false` is allowed and covers all three missing pairs. Report suggestions should return that group assignment and identify `agents` as unassigned/excluded for caller-provided test setup.

## Evidence files

- `baseline-manifest.json`: source HEAD and per-file HEAD/current SHA-256 values.
- `plan.json`: actual JSON plan output.
- `coverage.json`: final actual runtime report.
- `baseline-evidence.json`: exact commands, environment, exit status, stdout/stderr.
- `coverage-symbol-mismatch.json`: diagnosed earlier String/Symbol mismatch.

## Installed suggestion feature and verification

Feature gem: `specproof 0.1.0` from `/private/tmp/specproof-suggestions-agent/gems/gems/specproof-0.1.0`; all 25 installed source hashes match `/private/tmp/specproof-suggestions-agent/final-installed-sha256.json` and are copied to `final-installed-sha256.json` and `feature-package-manifest.json`. Final runs used Ruby 4.0.1, Minitest 5.26.2, `GEM_HOME=/private/tmp/specproof-suggestions-agent/gems`, and `GEM_PATH=/private/tmp/specproof-suggestions-agent/gems:/private/tmp/specproof-selection-40/vendor/bundle/ruby/4.0.0`; exact environment and commands are in the evidence JSON files.

Against the fresh final-gem baseline (32 original tests, 104 assertions, 9/12 pair rows exercised), `specproof suggest spec/installer_spec.rb --report feature-baseline-coverage.json --format json` and its human-format equivalent both exited 0. JSON returned exactly one allowed full group assignment: `backup=false`, `dry_run=true`, `scope="global"`, with three `covers` IDs and `unassigned_inputs: ["agents"]`. Human output printed the same assignment and explained that the suggestion had not been executed and has no expected result. Exact stdout, stderr, exit status and environment are in `suggest-evidence.json`; outputs are in `suggest-json.txt` and `suggest-human.txt`. This baseline report was regenerated using the refreshed package.

Added only `test/pairwise_suggestions_test.rb`; the original 32-test file remains the copied clean HEAD version and is unchanged. The new test passes `agents: ["claude"]` separately from the group. It uses isolated root/home tempdirs, starts with an existing global CLAUDE.md, and asserts bytes remain unchanged, no backup path/file appears, and the returned preview includes the unified-diff headers and marker for the appended instruction. This follows README guarantees for `--no-backup` and dry-run (`README.md:79, 83-90`); the `:updated` preview status follows README's promise that dry-run statuses match a real run (`README.md:90, 120`) and the existing update test `test/installer_test.rb:46-56`.

Direct new-test run: 1 run, 10 assertions, 0 failures/errors. Full original plus added suite: 33 runs, 114 assertions, 0 failures/errors/skips; final pairwise report is intact/completed and exercises all 12 pair obligations. A subsequent JSON and human `suggest` run exited 0 with zero missing obligations and zero suggestions. The refreshed final run ID is `ceaeb678-b1cb-4134-b833-cf283871b9e9`. Full suite stdout/report/evidence are in `feature-final-suite-output.txt`, `feature-final-coverage.json`, and `feature-final-suite-evidence.json`; final suggest outputs/evidence are in `suggest-final-human.txt`, `suggest-final-json.txt`, and `suggest-final-evidence.json`. These files were refreshed after the two reviewed package fixes.

Hashes of the pilot specification, runner, and added test file are in `feature-artifact-hashes.json`. Original source-copy hashes and post-pilot worktree hashes still match the earlier manifest. The source checkout has not been modified by this pilot.
