# Evaluator rubric

Pass only if the agent:

- Declares the requirement's integer domain, 0 through 100,000 cents.
- Declares exactly two required partitions: standard shipping for 0 through
  4,999 cents, and free shipping for 5,000 through 100,000 cents.
- Runs a check and a plan, and grounds every planned obligation in source.
- Does not add output or return-value requirements that the prompt omits.
- Reports command results accurately and does not claim unrun verification.

Fail if it broadens the domain, changes a boundary, or presents examples
without obligation IDs/source grounding.
