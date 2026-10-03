# PStoreLogger input-selection pilot

This pilot runs SpecProof against the unchanged PStoreLogger test suite from source commit `959e37410bac42ba47e43ee8da006ce9550d9f50`. The suite passes with its original Hash payloads: **7 tests, 23 assertions, 0 failures, 0 errors**.

The declaration analyzes only the effective `file_id` values `nil` and `1`, and excludes `data` with the reason recorded in the coverage report. This finite domain is a bounded scenario subset grounded in the ordinary suite, not a statement about the method’s full accepted `file_id` domain. The README documents string IDs; they are intentionally outside this milestone. No scalar-only tests were added; the report comes from the unchanged original suite.

Final report: run ID `e7fbe514-824c-4f77-8cac-6def94719933`, contract digest `9f91c6ddf296386ec79ad9229ee65c216b7c3d5cf540ee96fb2e8f0846c7c2d6`, 2/2 obligations exercised, integrity true. `nil` had 6 hits and `1` had 3. `scope.completeness_scope` is `analyzed_inputs`; `scope.input_scope` records `file_id` as analyzed and `data` as excluded. Check, plan, and coverage JSON plus raw command output are retained here.

## Reproduction

Requires CRuby 3.4.7, Bundler, Minitest 5.26.2, this SpecProof checkout, and the five unchanged source/test files under `project/`. The corresponding files use a `.txt` suffix so repository tooling does not treat pilot fixtures as executable code. Copy each file to the path shown by its name, dropping the final `.txt`; copy `specifications/pstore_logger_save.rb.txt` to `specifications/pstore_logger_save.rb`, `pilot_runner.rb.txt` to `pilot_runner.rb`, and `Gemfile.txt` to `Gemfile`. The pilot runner and specification snippets also use `.txt` suffixes for repository tooling.

Replace `<PILOT_ROOT>` with the reconstructed pilot directory. Create its `home` and `tmp` directories, set `SPECPROOF_ROOT` to the SpecProof checkout, then run these commands from the pilot root. This helper applies the same clean Ruby/Bundler environment to each command:

```sh
mkdir -p <PILOT_ROOT>/home <PILOT_ROOT>/tmp
pilot_ruby() {
  env -i HOME=<PILOT_ROOT>/home BUNDLE_USER_HOME=<PILOT_ROOT>/home TMPDIR=<PILOT_ROOT>/tmp PATH=/Users/luciang/.rubies/ruby-3.4.7/bin:/usr/bin:/bin BUNDLE_GEMFILE=<PILOT_ROOT>/Gemfile BUNDLE_PATH=<PILOT_ROOT>/vendor/bundle SPECPROOF_ROOT=/Users/luciang/Dropbox/workprojects/opensource/specproof/gems/specproof/tmp/worktrees/input-selection MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-3.4.7/bin/ruby "$@"
}
pilot_ruby -S bundle install
pilot_ruby -S bundle exec specproof check specifications/pstore_logger_save.rb --format json
pilot_ruby -S bundle exec specproof plan specifications/pstore_logger_save.rb --format json
pilot_ruby -S bundle exec ruby pilot_runner.rb baseline
pilot_ruby -S bundle exec ruby pilot_runner.rb instrumented
pilot_ruby -S bundle exec ruby runtime_probe.rb
```

`manifest.json` records the exact run arguments, original checkout status, all 17 SpecProof library hashes, and the runtime-loaded library paths. No vendor bundle, gem package, or archive is included.

`initial/` preserves the first instrumented report from before the final core freeze, separately from the final report. Final runs were fresh processes after the core library freeze. The original source checkout remained clean, and copied source/test files match the manifest hashes.
