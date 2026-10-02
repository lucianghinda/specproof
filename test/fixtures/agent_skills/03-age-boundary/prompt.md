# User prompt

Adults must be allowed to register starting at age 18. The current source uses
`age > 18`; existing tests cover 0, 1, 17, 119, and 120. Use SpecProof to
identify the missing age-18 evidence, add a meaningful regression assertion
for it, fix the boundary bug, and rerun the full test suite in a fresh command.
Every boundary assertion must retain its SpecProof obligation ID and cite the
source rule it checks.
