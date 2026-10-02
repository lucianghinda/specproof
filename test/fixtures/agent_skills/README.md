# Agent skill evaluations

Each evaluation keeps the user prompt and evaluator rubric outside `project/`.
Copy only the contents of a scenario's `project/` directory into a fresh
workspace for a baseline run. The rubric is evaluator-only and must not be
included in that workspace.

These six cases check that an agent follows the written workflow while it
works with the SpecProof command line. They are kept separate so one scenario's
instructions and artifacts cannot leak into another.
