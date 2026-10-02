# Optional `file_id` PStoreLogger pilot results

All runs used Ruby `ruby 3.4.7 (2025-10-08 revision 7a5688e2a2) +PRISM [arm64-darwin24]`, explicit `ruby -S bundle exec`, an environment with inherited Bundler/Ruby override variables plus `GEM_HOME` and `GEM_PATH` unset, and `MT_NO_PLUGINS=1`. Bundler then selected the pilot's local vendor bundle. The copied project source and original tests match every SHA-256 in `source-manifest.json`.

`specproof check` passed with no findings. `specproof plan` produced criterion `input-basics-v1` and contract digest `23dfd41312af281af643ee0bba8814f75f0bf516c822a9f5327d1b3319e84a18` for seven marginal obligations:

- `75813df6b054c3d81d47c9057cec632ff9a4e9defed20cb1278f220fe24a4979` — `data=nil`
- `3874140921e3437c727980fb01a191342d7da99369b58567152ed5e58fadc028` — `data=false`
- `f02029d5684e0dfa43f87049b3206b4314a8adf538cd2df66a8be1935ba6207b` — `data=true`
- `c8db4f2acf0ed75e7c86ef8d3ff08b1071d4c860dad11575cca9dd2d5c1cc985` — `data=0`
- `d94839f47e4e734c01ac3f4f0fae8b68bcc53ecae22340379221d8fa7fb0621b` — `data=:event`
- `5255739c08d32f0bbf9302e187f1f30091bd2adb33cda365520289cdab02348d` — `file_id=nil`
- `0e99f541e20b8eb00fba805504c215f28dd2b45e596e7d0210b75d49f13a7432` — `file_id=1`

- Original uninstrumented tests: **7 runs, 23 assertions, 0 failures, 0 errors**.
- Original instrumented tests: **7 runs, 23 assertions, 0 failures, 0 errors**; the Minitest subprocess exits 1 because coverage is incomplete with 7 unknown obligations after original Hash arguments trigger `non_primitive_argument`. Report run ID: `c063376a-17b7-46b6-b5b6-4a3a7af48dfb`. `tests_passed` is true; no Hash-domain coverage is claimed.
- Full uninstrumented suite after adding scalar tests: **13 runs, 63 assertions, 0 failures, 0 errors**.
- Full instrumented suite: tests passed, while its Minitest subprocess exits 1 because evidence remains incomplete after the original Hash calls trigger `non_primitive_argument`. This invocation recorded 7/7 marginal hits before collection became incomplete; it does not establish a complete suite report. Report run ID: `bab1e2a8-f6fb-44c3-8241-1d8c17e1d6f5`.
- Explicitly filtered `--name /test_specproof_scalar_/` run: **6 runs, 40 assertions, 0 failures, 0 errors**, with all 7/7 marginal obligations exercised and subprocess exit 0. This report applies only to the named scalar tests, not the whole project. Report run ID: `b8e67831-0515-4d49-82bd-5946879492ec`; digest: `23dfd41312af281af643ee0bba8814f75f0bf516c822a9f5327d1b3319e84a18`.

The scalar assertions inspect PStore key presence and exact values, including `nil` and `false`, and check timestamp metadata. The nil-data case omits `file_id`; the other scalar cases pass explicit `file_id: nil`. The explicit `file_id: 1` case verifies `1.pstore` and collision suffix `1_1.pstore`. As specified, omitted/default nil and explicit nil are one effective-value obligation; argument presence and combinations are not established. Ruby warns that PStore will no longer be part of the default gems starting with Ruby 3.5.

The runtime probe confirms the actual loaded SpecProof root is `/Users/luciang/Dropbox/workprojects/opensource/specproof/gems/specproof`; actual `$LOADED_FEATURES` paths and SHA-256 values are retained in `runtime_probe.json`. The exact exported skill files remain under `.agents/skills` with hashes in `commands-and-results.json`. Command lines, child exit statuses, raw logs, coverage reports, UUIDs, digest, and copied-source hashes are retained in `commands-and-results.json` and neighboring evidence files.
