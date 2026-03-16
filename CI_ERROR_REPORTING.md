# CI/CD Error Reporting for Wiggum Workers

This system automatically detects GitHub Actions failures and adds them to project TASKS.md so wiggum workers can auto-fix issues.

## How It Works

### 1. **Automatic CI Error Detection** (Recommended)
The wiggum workers automatically check for recent GitHub Actions failures at the start of each iteration via `check-ci-errors.sh`.

**What happens:**
- Worker starts an iteration
- Checks GitHub Actions for recent failed runs using `gh` CLI
- Finds any failures and extracts error details
- Adds them to TASKS.md as high-priority error tasks
- Worker then processes these error tasks like any other task

**Example error task added to TASKS.md:**
```markdown
- [ ] 🔴 CI Error: build (#42) - https://github.com/Julien-ser/edgebot-ai/actions/runs/12345
```

### 2. **GitHub Actions Workflow** (For Custom Projects)
If your project has its own GitHub Actions workflows, you can use the `report-ci-errors.yml` workflow that automatically commits error reports.

**Location:** `/Free-Wiggum-opencode/.github/workflows/report-ci-errors.yml`

**Setup for your project:**
```bash
cp /home/julien/Desktop/Free-Wiggum-opencode/.github/workflows/report-ci-errors.yml \
   /path/to/your/project/.github/workflows/
```

**How it works:**
- Listens for workflow failures
- Automatically adds errors to project's TASKS.md
- Commits the error report
- Wiggum workers then detect it and fix it

## Prerequisites

- **GitHub CLI (`gh`)** must be installed and authenticated
- GitHub repo must have been created and pushed
- TASKS.md file must exist in the project
- Workers need `read` and `write` permissions to TASKS.md and git

## Testing the System

### Test 1: Manually trigger a CI failure
```bash
cd /home/julien/Desktop/Free-Wiggum-opencode/projects/edgebot-ai
# Make a change that causes build to fail
git push  # This will trigger GitHub Actions
```

### Test 2: Check if error is detected
```bash
bash /home/julien/Desktop/Free-Wiggum-opencode/check-ci-errors.sh \
     /home/julien/Desktop/Free-Wiggum-opencode/projects/edgebot-ai
```

Expected output:
```
🔍 Checking CI errors for: Julien-ser/edgebot-ai
Found CI failures, adding to TASKS.md...
  ✅ Added: build #42
✅ CI error check complete
```

### Test 3: Verify TASKS.md was updated
```bash
head -5 /home/julien/Desktop/Free-Wiggum-opencode/projects/edgebot-ai/TASKS.md
# Should show the error task at the top
```

## How Workers Fix CI Errors

1. **Automatic Detection:** Worker reads error task from TASKS.md
2. **Context Gathering:** Worker uses the error URL to get full logs if needed
3. **Root Cause Analysis:** Worker analyzes the error
4. **Fix Implementation:** Worker modifies files and pushes fix
5. **Mark Complete:** Worker marks the CI error task as done (`[x]`)
6. **Retry Push:** Next iteration, GitHub Actions re-runs and (hopefully) succeeds

## Example: Fixing the `sensor_msgs` Error

Your edgebot-ai error:
```
error: no matching package named `sensor_msgs` found
location searched: crates.io index
required by package `edgebot-core v0.1.0`
```

The system will:
1. Add to TASKS.md: `- [ ] 🔴 CI Error: build (#NNN) - https://github.com/Julien-ser/edgebot-ai/actions/runs/XXX`
2. Worker reads this task
3. Worker examines Cargo.toml to see why `sensor_msgs` can't be found
4. Worker suggests using ROS2 message definitions or finding an alternative crate
5. Worker implements the fix by updating dependencies
6. Worker tests locally and pushes
7. CI runs again and hopefully succeeds
8. Worker marks task as `[x]` done

## Priority

CI error tasks are treated as **high-priority** because they block all other work. They appear at the top of TASKS.md and workers will work on them as soon as they're added.

## Supported CI Systems

Currently optimized for:
- **GitHub Actions** (all workflow types are monitored)
- Direct addition to TASKS.md

Could extend to:
- GitLab CI
- Jenkins
- CircleCI
- Travis CI

## Manual Error Reporting

If automatic detection fails, you can manually add errors:

```bash
cd /path/to/project
echo "- [ ] 🔴 CI Error: [Brief description of error] - Link to logs" >> TASKS.md
git add TASKS.md
git commit -m "Manual CI error report"
git push
```

## Troubleshooting

**Q: Errors aren't being detected**
- Check if `gh` is installed: `which gh`
- Check if authenticated: `gh auth status`
- Check if project is pushed to GitHub: `git remote -v`

**Q: TASKS.md isn't being updated**
- Verify file exists: `ls TASKS.md`
- Verify you have write permissions: `ls -l TASKS.md`
- Check logs: `bash /home/julien/Desktop/Free-Wiggum-opencode/check-ci-errors.sh /path/to/project`

**Q: Worker keeps failing on the same error**
- Error might be too complex for AI to fix automatically
- Add more context to the task: `- [ ] 🔴 CI Error: build - See issue #123 for context`
- Create a detailed GitHub issue that the worker can reference

## Monitoring

Check current CI errors across all projects:
```bash
for project in /home/julien/Desktop/Free-Wiggum-opencode/projects/*/; do
  echo "=== $(basename $project) ==="
  grep "🔴 CI Error" "$project/TASKS.md" 2>/dev/null || echo "No errors"
done
```
