# PStoreLogger string file ID pilot

This pilot extends the bounded `file_id` scenarios from `nil` and `1` to include the documented custom ID `"user_123"`. It excludes `data` because payload contents are outside these file ID scenarios. The five retained PStoreLogger source and test files are byte-for-byte unchanged from source commit `959e37410bac42ba47e43ee8da006ce9550d9f50`.

The declaration is in `specifications/pstore_logger_save.rb.txt`. A separate test file saves two payloads with `file_id: "user_123"`, checks the expected names `user_123.pstore` and `user_123_1.pstore`, and reads each file directly with PStore to verify the stored payload. It avoids `load_last` and file mtime ordering.

## Evidence

The unchanged source suite passes with 7 tests and 23 assertions. Under strict missing-input policy, instrumenting only that suite exits 1 as intended: tests pass, integrity is true, and coverage is 2/3 because the string value is unobserved. The additional string test makes the strict run exit 0 with 8 tests, 27 assertions, and 3/3 obligations exercised.

`reports/` retains check, plan, baseline coverage, final coverage, and runtime probe JSON. `logs/` retains each command's stdout, stderr, and exit status. `manifest.json` records the exact run IDs, contract digest, commands, Ruby library hashes, and before/after hashes for the original five source files. The source hashes all match.

## Reproduction

Reconstruct a scratch pilot directory from this directory by copying the `.txt` artifacts and dropping the final `.txt` from executable and source filenames. For example, copy `project/lib/pstore/logger.rb.txt` to `project/lib/pstore/logger.rb`, `project/test/test_pstore_logger_strings.rb.txt` to `project/test/test_pstore_logger_strings.rb`, `specifications/pstore_logger_save.rb.txt` to `specifications/pstore_logger_save.rb`, `pilot_runner.rb.txt` to `pilot_runner.rb`, `baseline_instrumented_runner.rb.txt` to `baseline_instrumented_runner.rb`, `runtime_probe.rb.txt` to `runtime_probe.rb`, and `Gemfile.txt` to `Gemfile`. Do the same for the other four retained project files and create `home`, `tmp`, and `evidence` directories.

The recorded environment used CRuby 3.4.7, Minitest 5.26.2, and this SpecProof worktree. Set `SPECPROOF_ROOT` to the SpecProof checkout and use the same Bundler settings. From the reconstructed pilot directory, the commands were:

```sh
env -i HOME=<PILOT_ROOT>/home BUNDLE_USER_HOME=<PILOT_ROOT>/home TMPDIR=<PILOT_ROOT>/tmp PATH=/Users/luciang/.rubies/ruby-3.4.7/bin:/usr/bin:/bin BUNDLE_GEMFILE=<PILOT_ROOT>/Gemfile BUNDLE_PATH=/private/tmp/specproof-selection-34/vendor/bundle SPECPROOF_ROOT=<SPECPROOF_ROOT> MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-3.4.7/bin/ruby -S bundle exec specproof check specifications/pstore_logger_save.rb --format json
env -i HOME=<PILOT_ROOT>/home BUNDLE_USER_HOME=<PILOT_ROOT>/home TMPDIR=<PILOT_ROOT>/tmp PATH=/Users/luciang/.rubies/ruby-3.4.7/bin:/usr/bin:/bin BUNDLE_GEMFILE=<PILOT_ROOT>/Gemfile BUNDLE_PATH=/private/tmp/specproof-selection-34/vendor/bundle SPECPROOF_ROOT=<SPECPROOF_ROOT> MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-3.4.7/bin/ruby -S bundle exec specproof plan specifications/pstore_logger_save.rb --format json
env -i HOME=<PILOT_ROOT>/home BUNDLE_USER_HOME=<PILOT_ROOT>/home TMPDIR=<PILOT_ROOT>/tmp PATH=/Users/luciang/.rubies/ruby-3.4.7/bin:/usr/bin:/bin BUNDLE_GEMFILE=<PILOT_ROOT>/Gemfile BUNDLE_PATH=/private/tmp/specproof-selection-34/vendor/bundle SPECPROOF_ROOT=<SPECPROOF_ROOT> MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-3.4.7/bin/ruby -S bundle exec ruby pilot_runner.rb baseline
env -i HOME=<PILOT_ROOT>/home BUNDLE_USER_HOME=<PILOT_ROOT>/home TMPDIR=<PILOT_ROOT>/tmp PATH=/Users/luciang/.rubies/ruby-3.4.7/bin:/usr/bin:/bin BUNDLE_GEMFILE=<PILOT_ROOT>/Gemfile BUNDLE_PATH=/private/tmp/specproof-selection-34/vendor/bundle SPECPROOF_ROOT=<SPECPROOF_ROOT> MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-3.4.7/bin/ruby -S bundle exec ruby baseline_instrumented_runner.rb
env -i HOME=<PILOT_ROOT>/home BUNDLE_USER_HOME=<PILOT_ROOT>/home TMPDIR=<PILOT_ROOT>/tmp PATH=/Users/luciang/.rubies/ruby-3.4.7/bin:/usr/bin:/bin BUNDLE_GEMFILE=<PILOT_ROOT>/Gemfile BUNDLE_PATH=/private/tmp/specproof-selection-34/vendor/bundle SPECPROOF_ROOT=<SPECPROOF_ROOT> MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-3.4.7/bin/ruby -S bundle exec ruby pilot_runner.rb instrumented
env -i HOME=<PILOT_ROOT>/home BUNDLE_USER_HOME=<PILOT_ROOT>/home TMPDIR=<PILOT_ROOT>/tmp PATH=/Users/luciang/.rubies/ruby-3.4.7/bin:/usr/bin:/bin BUNDLE_GEMFILE=<PILOT_ROOT>/Gemfile BUNDLE_PATH=/private/tmp/specproof-selection-34/vendor/bundle SPECPROOF_ROOT=<SPECPROOF_ROOT> MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-3.4.7/bin/ruby -S bundle exec ruby runtime_probe.rb
```

The `baseline_instrumented_runner.rb` used to establish 2/3 is the unchanged-suite runner with strict coverage enabled; its source is the pilot runner without the conditional string-test require. No vendor bundle or dependency archive is retained in this pilot.
