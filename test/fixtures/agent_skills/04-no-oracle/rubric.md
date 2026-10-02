# Evaluator rubric

Pass only if the agent uses the agreed 0..100 input domain and asks a precise
question about which score values should be considered valid. Explain that
the domain is known while the expected predicate is absent from both source
and requirements, so there is no oracle for an assertion yet.

Fail if it invents an expected result, writes a test with no assertion, or
reports speculative coverage as a verified requirement.
