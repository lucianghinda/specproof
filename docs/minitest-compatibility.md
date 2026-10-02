# Reproducible Minitest installation

The optional adapter accepts Minitest `>= 5.26.2` and `< 5.28.0`. Both the activated gem metadata and `Minitest::VERSION` must be in that range, with matching major and minor versions. The lower bound excludes untested 5.26.0 and 5.26.1; the upper bound excludes untested later interfaces.

The development and pilot bundles select `~> 5.26.2`. An ordinary bundle uses the existing RubyGems dependency without a source rebuild, a runtime version patch, or an alternate GEM_HOME:

```sh
bundle install
bundle exec rake
bundle exec ruby -rminitest -e 'puts Gem.loaded_specs.fetch("minitest").version; puts Minitest::VERSION'
```

Use Ruby 3.3 or newer for these commands. The last command reports `5.26.2` twice with the checked-in lockfile.

## Observed package mismatch

On 2026-10-02, a fresh download from [RubyGems' Minitest 5.27.0 package](https://rubygems.org/downloads/minitest-5.27.0.gem) matched the SHA-256 in its [published metadata](https://rubygems.org/api/v2/rubygems/minitest/versions/5.27.0.json):

`2d3b17f8a36fe7801c1adcffdbc38233b938eb0b4966e97a6739055a45fa77d5`

Its gem metadata says `5.27.0`, but the extracted `lib/minitest.rb` defines `VERSION = "5.26.2"`. This observation concerns the published artifact downloaded on that date; the [upstream v5.27.0 source](https://github.com/minitest/minitest/blob/v5.27.0/lib/minitest.rb) declares `5.27.0`. Reinstalling the same artifact preserves the mismatch. SpecProof continues to reject it.

A fresh [5.26.2 package](https://rubygems.org/downloads/minitest-5.26.2.gem) matched its [published metadata](https://rubygems.org/api/v2/rubygems/minitest/versions/5.26.2.json):

`f021118a6185b9ba9f5af71f2ba103ad770c75afde9f2ab8da512677c550cde3`

That package's metadata and extracted runtime both identify `5.26.2`. Its `lib/minitest.rb` also matches the existing local installation by SHA-256. No dependency source or global gem installation was modified.

## Validation and historical evidence

New integration tests exercise genuine 5.26.2 and reject the mislabeled 5.27/5.26 pairing, the reverse pairing, versions below the lower bound, 5.28.0, and 6.0.0. The original 5.27 source-tag validation and retained skill evaluations remain historical evidence; they were not rewritten to claim that the mismatched published artifact passed.

Compatibility changes do not alter the criterion, obligation IDs, JSON schema, collector scope, or the distinction between input exercise and behavioral correctness.
