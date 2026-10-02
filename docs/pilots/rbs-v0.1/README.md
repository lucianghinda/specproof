# RBS compatibility and existing-project pilot

## Compatibility

Published RBS 4.2.0 (`ruby` platform) and Minitest 5.26.2 were installed normally into isolated bundles for CRuby 3.3.6, 3.4.7, and 4.0.1. Each bundle resolved SpecProof to the live implementation worktree, without a generated path-gem cache. Commands used `env -i` with the matching Ruby path, a scratch home/temp directory, and explicit bundle paths; incompatible ambient Ruby/Gem/Bundler variables were absent.

| Ruby | Core | Optional RBS suites | Failures / errors / skips |
| --- | --- | --- | --- |
| 3.3.6 | 156 tests, 786 assertions | 39 tests, 396 assertions | 0 / 0 / 0 |
| 3.4.7 | 156 tests, 786 assertions | 39 tests, 396 assertions | 0 / 0 / 0 |
| 4.0.1 | 156 tests, 786 assertions | 39 tests, 396 assertions | 0 / 0 / 0 |

Raw command/output logs, package paths/versions, and bundle files are in [matrix/33](matrix/33), [matrix/34](matrix/34), and [matrix/40](matrix/40). `FINAL-*` files are the final runs after the input-binding fix. Earlier `post-correction-*` results are retained separately. Bundle-file bytes are stored with `.txt` suffixes as evidence, not executable project configuration. The optional suites explicitly include `test/rbs/source_test.rb` and `test/rbs/workflow_test.rb`; they were run, not skipped for parser absence. Default-bundle Ruby 4.0.1 `bundle exec rake` also passed 156 tests/786 assertions and inspected 95 files with no lint offenses. Signature validation passed separately in `Gemfile.rbs`.

The checked [published package hashes](verified-packages.json) identify the normal CRuby packages. The unqualified RubyGems RBS version endpoint initially selected a Java package; the platform-specific lookup confirmed that the CRuby cache matched its published checksum. No global gem or dependency was modified.

## Existing RBS adoption

A [bounded local survey](adoption-survey.json) examined seven project locations with RBS files and found a suitable existing target in BranchProof. Several projects had only constants or empty signatures; other candidates used unsupported strings, objects, generics, aliases, or unrestricted integers. One constructor near-match lacked a direct assertion source for this pilot. These are survey selection limits, not claims that every method in those projects is unsupported.

The unchanged BranchProof snapshot is commit `85611af97461d1714bffffff42a4719952b9cbc4`. Its existing signature at `sig/branchproof.rbs:355` supplies `fail_on_regression: bool` for `Branchproof::ComparisonReport#exit_code`. Offline RBS-only check and plan pass; runtime collection observes both obligations without a duplicate DSL declaration. The original focused test file passes **2 tests, 8 assertions** before and after installation. No behavior gap or test addition was manufactured.

Read [the pilot result](branchproof/RESULT.md), [source manifest](branchproof/source-manifest.json), and [skill/package hashes](branchproof/skill-and-package-manifest.json). The [workspace archive](branchproof/workspace.tar.gz) includes all 59 unchanged source files, original signatures, the focused test files, exact commands/logs, the fresh 2/2 report, runtime package metadata, runner, and the current exported skills. Installed gems and generated caches are excluded; [the archive manifest](branchproof/workspace-manifest.json) hashes retained files.

The runtime runner explicitly requires `branchproof/comparison_report` before installing the collector. The adapter then receives `specifications: []`, the original RBS file, and the selected target. It loads only `project/test/test_comparison_report.rb`. This is focused adoption evidence, not a full BranchProof suite result. Return-code assertions come from the existing tests, not the RBS return type.

## Reproduce the pilot

Extract the archive into a new scratch directory. Use Ruby 4.0.1 (BranchProof itself requires Ruby 4), set `SPECPROOF_ROOT` to this SpecProof gem checkout, and install the archive's normal bundle. Clear incompatible ambient Ruby/Gem/Bundler variables before running. From the extracted root:

```sh
bundle install
bundle exec specproof check --rbs project/sig/branchproof.rbs --target 'Branchproof::ComparisonReport#exit_code' --format json
bundle exec specproof plan --rbs project/sig/branchproof.rbs --target 'Branchproof::ComparisonReport#exit_code' --format json
bundle exec ruby -Iproject/test logs/run_branchproof_rbs_coverage.rb
```

Recorded absolute paths describe the original execution; the Ruby runner resolves the extracted project paths. A reproduction produces a new UUID and scope paths and may choose another Minitest seed. Its two obligation IDs and behavioral digest should remain unchanged. Keep the archived evidence intact and reproduce in a separate directory.
