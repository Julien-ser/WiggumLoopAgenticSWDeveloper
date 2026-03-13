# Project Template

This is a template for new projects created via `wiggum_master.sh create`.

Each project:
- Lives in `projects/<project-name>/`
- Has its own GitHub repository
- Runs its own autonomous OpenCode agent loop
- Tracks progress in TASKS.md

## Setup

1. Create: `bash wiggum_master.sh create "my-project" "Description"`
2. View: `cat projects/my-project/README.md`
3. Initialize: `cd projects/my-project && opencode /init --yes`
4. Run: `cd projects/my-project && bash wiggum.sh`

## Files

- **README.md** - Project documentation
- **TASKS.md** - Development task list
- **prompt.txt** - Agent instructions (project-specific)
- **AGENTS.md** - Project context (auto-generated)
- **src/** - Source code directory
- **tests/** - Test files

## Customization

Update TASKS.md with your project goals, then let the agent handle it!
