# Evaluation result

The existing specification matches the stated integer input contract for `Checkout#shipping`. SpecProof 0.1.0 reported no check errors or findings. Its plan produced six boundary candidates: `0`, `1`, `4,999`, `5,000`, `99,999`, and `100,000`. These are candidates, not a complete or proven test suite.

## Provenance

- Skill: `.agents/skills/specproof-specify/SKILL.md`
  - SHA-256: `feee53fcb41d8a6f3dc8ac11e0aab94be7e7e760a510ee0a6fad171cbd7f045c`
- Skill reference: `.agents/skills/specproof-specify/references/usage.md`
  - SHA-256: `97c3c89ade4bf6a211e596b903018fba78f0cf5aa383823743bdafbdbadcc943`
- Version command: `GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof --version`
  - Result: `SpecProof 0.1.0`
- Check command: `GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof check specifications/checkout.rb --format json`
  - Result: schema 1, SpecProof 0.1.0, no errors or findings; contract digest `26f4b60e61f1c2010df1ce171b70654fd488bfb2b7b66a2e7a62a713be37528f`.
- Plan command: `GEM_HOME=/private/tmp/specproof-validation-gems GEM_PATH=/private/tmp/specproof-validation-gems MT_NO_PLUGINS=1 /Users/luciang/.rubies/ruby-4.0.1/bin/ruby /private/tmp/specproof-validation-gems/bin/specproof plan specifications/checkout.rb --format json`
  - Result: schema 1, SpecProof 0.1.0, criterion `input-basics-v1`, no errors; same contract digest. The six values and their reasons/source locations are included below.

## Contract and source comparison

`requirements.md` sets the closed integer domain `0..100_000`, with `standard` covering `0..4_999` and `free` covering `5_000..100_000`. The declaration in `specifications/checkout.rb:2-5` declares those bounds with `exhaustive: true` and `disjoint: true`, as the stated ranges cover the domain without overlap. The source is `checkout.rb:2-4`; the comparison threshold is 5,000 cents and agrees with the stated partition boundary for supported inputs. No output behavior has been declared.

| Candidate | Reason | Declaration source |
| ---: | --- | --- |
| 0 | input lower endpoint; standard lower endpoint | `specifications/checkout.rb:2-3` |
| 1 | input lower neighbor | `specifications/checkout.rb:2` |
| 4,999 | standard upper endpoint | `specifications/checkout.rb:3` |
| 5,000 | free lower endpoint | `specifications/checkout.rb:4` |
| 99,999 | input upper neighbor | `specifications/checkout.rb:2` |
| 100,000 | input upper endpoint; free upper endpoint | `specifications/checkout.rb:2,4` |

## Changes and uncertainty

Changed files: `RESULT.md` only. The existing specification already met the requested contract, so it was left unchanged. The fixture README states there is no test suite. The task intentionally specifies only inputs, so this report makes no claim about required outputs, invalid-input handling, or behavior outside the declared domain.
