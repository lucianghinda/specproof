# Lint cleanup plan

The implemented behavior is protected by the 102-test suite, including runtime and installed-package checks. Repository-wide RuboCop currently reports style and complexity offenses against the Bundler scaffold's defaults.

1. Run the existing RuboCop dependency with a writable cache and without parallel workers; collect the actual offense inventory.
2. Apply only safe style corrections, keeping the public API, report schema, and runtime behavior intact.
3. Treat test/fixture blocks separately from production complexity. `.rubocop.yml` excludes Metrics only under `test/**/*`, `spec/**/*`, and `benchmark/**/*`: cohesive test scenarios and benchmark support are not useful production complexity signals. Production Metrics remain enabled without per-file exclusions.
4. Set explicit initial project budgets after reviewing the actual inventory: ABC 60, cyclomatic/perceived complexity 20, method length 60, class length 250, module length 200, and block length 40. These replace scaffold defaults, including the ten-line method limit, which would fragment the interval sweep and sequential method-binding checks without changing their responsibilities. An independent Luna review found these algorithms cohesive and supported the budgets; the collector binding validator remains near the limits and should be monitored. These budgets are an initial policy, not evidence that complexity has disappeared.
5. Extract the oversized CLI dispatcher into separate check, plan, and skill-export flows with shared error handling. Preserve command behavior through the existing CLI acceptance tests; add regression tests for any behavior fixes.
6. Re-run affected tests after edits, then the complete suite, syntax/package checks, and RuboCop. Add no dependencies.

Ownership is limited to Ruby style corrections, existing `.rubocop.yml`, and this verification record. Agent evaluation projects in `/private/tmp` are independent evidence and must remain untouched.
