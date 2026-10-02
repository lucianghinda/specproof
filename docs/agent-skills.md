# Agent skills

SpecProof ships two optional Agent Skills alongside the Ruby gem. Export them
into an application's own skill directory with an explicit destination:

```sh
specproof skills export --to .agents/skills
```

The command copies `specproof-specify/` and `specproof-test-gaps/` into that
directory. Repeating the command leaves identical files alone. If a packaged
file would overwrite different content, export reports a conflict before
writing any skill files. Other files in the destination, including local files
inside either skill folder, are kept. An interrupted filesystem operation can
still leave a partial copy; rerun the command after correcting the reported
filesystem issue.

The skills also document the opt-in RBS workflow: inspect explicitly selected
signatures, reuse supported finite input types, and add only requirement-backed
behavioral refinements. The gap-review skill requires fresh runtime evidence
and checks imported declaration scope, report integrity, test results, and the
actual test command. RBS supplies no output oracle. Earlier evaluation results
in this document's linked record describe the workflows and artifacts named
there; they do not establish agent performance for this newer RBS workflow.

For Codex repository discovery, place the exported folders under
`.agents/skills` in the repository. Codex searches that directory from the
current working directory through its repository ancestors. Open a new Codex
session in the project and ask for one of the named skills to confirm it is
available. This discovery check is separate from the export result: export
confirms that files were copied, while the client session confirms that the
client found and loaded them. See the [Codex skills guide](https://learn.chatgpt.com/docs/build-skills)
and the [Agent Skills format](https://agentskills.io/specification).

Keep skill use opt-in. The exporter writes only to the path supplied by the
caller; it does not select a home directory, edit global configuration, alter
`AGENTS.md`, or access the network. The packaged skills and their local
references are self-contained, so the exported folder can be reviewed and
removed as ordinary project files.

The current RBS workflow was exercised in six fresh, isolated native Luna
tasks using skills exported from an installed gem. See the [RBS evaluation
record](evaluations/rbs-agent-skills-v0.1.md) for actual outcomes, retained
commands and reports, and the limits of these guided scenarios.

The export and one specification workflow were exercised in Codex CLI
`0.160.0` with `gpt-6-luna`, using `.agents/skills` in an isolated project and
the installed gem rather than this checkout. A separate fresh formatting task
did not load either SpecProof skill or create specifications. See the
[evaluation record](evaluations/agent-skills-v0.1.md) for retained artifacts,
baseline observations, repeated attempts, and limitations. These checks are
bounded observations of agent behavior, not a guarantee for every agent or
client. Other clients can receive the same exported folders through their
documented manual skill installation workflow; they have not been tested here.
