# WiggumLoop documentation

The detailed reference. For a short overview, see the [README](README.md).

- [Architecture](#architecture)
- [Setup notes](#setup-notes)
- [Commands](#commands)
- [Writing tasks](#writing-tasks)
- [Agent roles](#agent-roles)
- [Stuck detection](#stuck-detection)
- [The Jev judge](#the-jev-judge)
- [CI error handling](#ci-error-handling)
- [Web dashboard](#web-dashboard)
- [Configuration](#configuration)
- [Repository layout](#repository-layout)
- [Troubleshooting](#troubleshooting)
- [More guides](#more-guides)

## Architecture

One master script manages projects. Each project has its own folder, its own GitHub repo and its own worker process.

```mermaid
graph TB
    Master["wiggum_master.sh<br/>create / start / stop / status"]

    subgraph Projects
        W1["Worker A<br/>wiggum_worker.sh"]
        W2["Worker B<br/>wiggum_worker.sh"]
    end

    Master -->|creates and starts| W1
    Master -->|creates and starts| W2

    W1 -->|runs| OC["OpenCode agent"]
    W2 -->|runs| OC
    OC -->|model calls| OR["OpenRouter"]
    W1 -->|commits, PR| GH["GitHub<br/>one repo per project"]
    W2 -->|commits, PR| GH
    W1 -->|diff after each iteration| Jev["Jev judge"]
    W2 -->|diff after each iteration| Jev
```

### One worker iteration

```mermaid
flowchart LR
    A["Read TASKS.md"] --> B["Take the first<br/>unchecked task"]
    B --> C["Build the prompt:<br/>prompt.txt + role + task"]
    C --> D["Run OpenCode"]
    D --> E["Commit"]
    E --> F["Jev judge<br/>scores the diff"]
    F --> G["Push to the<br/>session branch"]
    G --> H{"Tasks left?"}
    H -->|yes| A
    H -->|no| I["Done"]
```

The worker commits to a `wiggum/session` branch. Merge it into `main` when the task list is finished: the worker tries to open a pull request itself, but that step is not reliable yet (it did not fire in the example run).

## Setup notes

WiggumLoop was written for one Linux machine, and two paths still point at it. Change both to your clone's location before the first run:

- `MASTER_DIR` at the top of `wiggum_master.sh`
- the `.env` path near the top of `wiggum_worker.sh` (the block that loads `OPENROUTER_API_KEY`)

Prerequisites:

```bash
npm install -g opencode-ai     # the coding agent
gh auth login --web            # the worker creates repos and pull requests
pip install -r requirements.txt   # only for the web dashboard
```

New projects are created as **public** GitHub repos under your account.

## Commands

```bash
bash wiggum_master.sh create "name" "What the project should do"   # scaffold, create repo, start a worker
bash wiggum_master.sh start "name"      # start a worker for an existing project
bash wiggum_master.sh stop "name"       # stop it
bash wiggum_master.sh status "name"     # progress for one project
bash wiggum_master.sh list              # all projects
bash wiggum_master.sh running           # running workers
bash wiggum_master.sh stop-all
```

Running `bash wiggum_master.sh` with no arguments opens an interactive menu.

Worker output goes to `projects/<name>/logs/`: one `iteration-N.md` per iteration, a `worker-session-*.log` per run, and `jev-decisions.jsonl` for the judge.

## Writing tasks

`create` asks the model to write `projects/<name>/TASKS.md` from your description. If that fails it falls back to a generic template, so check the file and replace vague tasks with specific ones.

```markdown
- [ ] Task 1: Create the package skeleton with an argparse entry point and a tests/ folder
- [ ] Task 2: Implement convert(rows) in core.py with pytest tests
- [ ] Task 3: Add reading from stdin, with pytest tests
```

- One task per line, starting with `- [ ]`. The worker always takes the first unchecked one.
- Keep tasks small and verifiable. Ask for tests in the task itself.
- Avoid quotes and backticks in task text. The worker passes it through the shell.

## Agent roles

A project can switch its worker to a specialist prompt for a phase of work.

| Role | Best for |
|------|----------|
| `generic` | General full-stack development |
| `devops-engineer` | CI/CD, deployment, infrastructure |
| `qa-specialist` | Testing, quality gates |
| `release-manager` | Versioning, releases |
| `documentation-specialist` | Docs, READMEs, API specs |
| `project-orchestrator` | Planning, delegation |

```bash
cd projects/my-project
echo "qa-specialist" > .agent_role
```

The next iteration loads `agents/qa-specialist.md`. Details are in [AGENT_ROLES.md](AGENT_ROLES.md).

## Stuck detection

When a task shows no progress for three or more iterations, the worker tries, in order:

1. **Decompose**: ask the agent to complete one small piece of the task.
2. **Skeleton files**: create minimal placeholder files to unblock it.
3. **Skip**: mark the task `[DEBUG-NEEDED]` and move on.

It also detects a task that keeps failing the same tests.

This does not catch every stall. In the example run below, the agent spent 16 iterations re-checking a task that was already finished before it ticked the box.

## The Jev judge

After every committed iteration, `jev_judge.py` sends the iteration's diff, the task text and the end of the iteration log to [Jev](https://openrouter.ai/docs/guides/community/jev) (`typesafe/jev-1.13`, using the same `OPENROUTER_API_KEY`). Jev is a decision model: it returns a probability for each question instead of text.

| Field | Question |
|---|---|
| `done` | Is the task fully completed? |
| `progress` | Did this iteration make meaningful progress? |
| `cheated` | Did the diff weaken tests or checks to make things pass? |
| `out_of_scope` | Did the diff change things the task did not ask for? |

Answers are appended to `logs/jev-decisions.jsonl` in the project.

- **Observation only.** The judge never changes what the loop does, and it cannot break it: any error is logged and ignored.
- **What it sees.** Everything committed since the start of the iteration, excluding `logs/`. Iterations with no code changes are logged as `skipped`.
- **Cost.** About $0.0001 per verdict in the example run.
- **Turn it off** with `JEV_JUDGE=off`.

### Labelled test

Twelve hand-written iterations, four questions each, Jev against `gpt-4o-mini` asked the same questions ([eval/RESULTS.md](eval/RESULTS.md)):

| | Jev | gpt-4o-mini |
|---|---|---|
| Accuracy | 85% | 77% |
| Brier score (lower is better) | 0.101 | 0.163 |
| Cheats caught | 4 of 4 | 2 of 4 |

Twelve cases written and labelled by the author is a smoke test, not a benchmark. Reproduce it with `python3 eval/judge_eval.py` (under $0.01).

### Live run

[csv2md-wiggum](https://github.com/Julien-ser/csv2md-wiggum): 8 tasks, 37 iterations, 32 passing tests, on `poolside/laguna-s-2.1:free`. The judge gave 9 scored verdicts and skipped 18 iterations with no code changes.

- `cheated` stayed low on every verdict (highest 0.16). The agent did not cheat in this run, so it did not test cheat detection live.
- `progress` was high on 8 of 9. The one low score was a five-line change with no tests.
- `done` is not reliable per iteration. The judge sees one iteration's diff, and a task often spans several.
- `out_of_scope` is noisy.

Next steps: stop the loop when several iterations in a row show no progress, then let `cheated` revert an iteration.

## CI error handling

Each project gets GitHub Actions workflows. When a build or test fails, the worker pulls the error into `TASKS.md` and the agent handles it:

- **Code errors**: fix the code.
- **Dependency or version errors**: update the version constraints.
- **Environment errors**: mark the task `[CI-SKIP]` and document the prerequisite.

The agent only changes code, configuration and version numbers. It does not install system tools. See [CI_ERROR_REPORTING.md](CI_ERROR_REPORTING.md) and [GITHUB_WORKFLOWS.md](GITHUB_WORKFLOWS.md).

## Web dashboard

```bash
pip install -r requirements.txt
python3 server.py        # http://localhost:5000
```

Shows project status and logs, and lets you create, start and stop projects from the browser.

<p align="center">
    <img src="./ui1.png" alt="Project view" width="48%"/>
    <img src="./ui2.png" alt="Project detail" width="48%"/>
</p>

Voice control is optional: see [VOICE_SERVER.md](VOICE_SERVER.md) and [VOSK_SETUP.md](VOSK_SETUP.md).

## Configuration

`.env` in the repo root:

```bash
OPENROUTER_API_KEY=sk-or-v1-...                       # required
WIGGUM_MODEL=openrouter/poolside/laguna-s-2.1:free    # the coding model
WIGGUM_UNSTICK_MODEL=...                              # optional, used by stuck recovery
```

Environment switches:

| Variable | Default | Effect |
|---|---|---|
| `JEV_JUDGE` | `on` | Set to `off` to skip the judge |
| `JEV_MODEL` | `typesafe/jev-1.13` | Judge model |
| `GITHUB_USER` | `git config user.name` | Account that owns new repos |

**Set `WIGGUM_MODEL` explicitly.** Free models on OpenRouter come and go, and the fallback built into the scripts no longer exists. Pick a current free model that supports tool calls from the [model list](https://openrouter.ai/models).

## Repository layout

```
├── wiggum_master.sh              # project management CLI
├── wiggum_worker.sh              # the loop that runs one project
├── wiggum_worker_manager.sh      # start/stop/monitor persistent workers
├── wiggum_worker_persistent.sh   # long-running worker variant
├── jev_judge.py                  # the judge
├── eval/                         # labelled test for the judge
├── server.py, templates/         # web dashboard
├── agents/                       # specialist role prompts
├── project_template/             # copied into every new project
├── check-ci-errors.sh, ci-debug.sh, extract-ci-error.sh
└── projects/                     # created at runtime, one folder per project
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `opencode: command not found` | `npm install -g opencode-ai`, and make sure the npm global bin folder is on `PATH` |
| Worker starts but the agent does nothing | `WIGGUM_MODEL` points at a model that no longer exists. Pick a current one. |
| Repo not created, or pushes fail | `gh auth status`, then `gh auth login --web` |
| API key not picked up | Check the `.env` path in `wiggum_worker.sh` (see [Setup notes](#setup-notes)) |
| `TASKS.md` is a generic template | Task generation failed. Write the tasks by hand. |
| No lines in `jev-decisions.jsonl` | Check `worker-session-*.log` for `[jev observe]` lines |

## More guides

- [GETTING_STARTED.md](GETTING_STARTED.md): longer walkthrough of the worker manager and agent team
- [MASTER_README.md](MASTER_README.md): master system architecture
- [SYSTEM_INTEGRATION.md](SYSTEM_INTEGRATION.md): what is wired together and how
- [AGENT_ROLES.md](AGENT_ROLES.md), [GITHUB_WORKFLOWS.md](GITHUB_WORKFLOWS.md), [CI_ERROR_REPORTING.md](CI_ERROR_REPORTING.md), [VOICE_SERVER.md](VOICE_SERVER.md), [VOSK_SETUP.md](VOSK_SETUP.md)
