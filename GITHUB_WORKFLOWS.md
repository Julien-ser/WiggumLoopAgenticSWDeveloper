# GitHub Actions Workflows Integration

Wiggum automatically sets up GitHub Actions workflows for every project created. These workflows provide CI/CD automation, testing, and validation.

## What Gets Set Up

When a new project is created, the following workflow files are automatically copied to `.github/workflows/`:

### 1. **test.yml** - Continuous Testing
Triggered on every push and pull request to `main` and `develop` branches

**Runs:**
- Dependency installation via `uv pip`
- Linting with `ruff`
- Type checking with `mypy` (if applicable)
- Tests with `pytest`
- Security checks

**Applies to:** Python projects

### 2. **deploy-staging.yml** - Staging Deployment
Triggered on pushes to `develop` branch after tests pass

**Runs:**
- Build and test
- Deploy to staging environment
- Run smoke tests on staging

**Applies to:** Web applications, APIs

### 3. **deploy-production.yml** - Production Deployment
Triggered on pushes to `main` branch with manual approval gate

**Runs:**
- Full test suite
- Security scanning
- Build production artifacts
- Deploy to production
- Health checks

**Applies to:** Production-ready applications

### 4. **wiggum-system-check.yml** - Wiggum Worker Health
Monitors Wiggum worker status and reports issues

**Runs:**
- Every 30 minutes
- Checks if project is complete
- Validates project structure
- Reports worker health

## How It Integrates

### Project Creation Flow

```
1. User creates project via web UI or CLI
   ↓
2. wiggum_master.sh copies .github/workflows/ directory
   ↓
3. Workflows appear in project repo
   ↓
4. First git push triggers CI/CD pipeline
   ↓
5. Tests run, staging deploys if successful
   ↓
6. Production deployment requires manual approval
```

### Per-Project Configuration

Each project can customize workflows by editing `.github/workflows/*.yml`:

```bash
cd projects/my-project
# Edit workflows
nano .github/workflows/test.yml
git add .github/workflows/
git commit -m "chore: customize CI/CD workflow"
git push
```

## Workflow Files Location

```
projects/
├── portfolio-website-terminal/
│   └── .github/
│       └── workflows/
│           ├── test.yml                    ← Runs tests
│           ├── deploy-staging.yml          ← Stages on develop
│           ├── deploy-production.yml       ← Deploys on main (requires approval)
│           └── wiggum-system-check.yml     ← Health checks
│
├── agentic-founders-finding/
│   └── .github/
│       └── workflows/
│           └── (same structure)
│
└── ...
```

## Environment Variables Required

Each project's GitHub repository should have these secrets configured for workflows to function:

### For Deployment Workflows

```
GITHUB_TOKEN              (auto-provided by GitHub Actions)
DEPLOY_KEY                (SSH key for staging/prod)
STAGING_URL               (staging environment URL)
PRODUCTION_URL            (production environment URL)
```

### For Wiggum Workflows

```
WIGGUM_ADMIN_EMAIL        (notification email for health checks)
WIGGUM_SLACK_WEBHOOK      (optional: Slack notifications)
```

## Monitoring Workflow Status

### Via GitHub Web UI

1. Go to your project repo on GitHub
2. Click **Actions** tab
3. See all workflow runs, their status, and logs

### Via Wiggum Web Dashboard

(Coming soon - workflow status integration)

### Via CLI

```bash
# Check workflow status
gh workflow list

# View specific workflow run
gh run list --workflow test.yml

# Watch run in real-time
gh run watch <run-id>
```

## Customizing Workflows

### Add a Custom Test Command

Edit `projects/my-project/.github/workflows/test.yml`:

```yaml
- name: Run Custom Tests
  run: |
    # Your custom test command
    python -m pytest tests/ -v --cov=src/
```

### Add Slack Notifications

```yaml
- name: Notify Slack on Failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Build failed for ${{ github.repository }}"
      }
```

### Skip Deployment for Certain Commits

```yaml
if: "!contains(github.event.head_commit.message, '[skip-deploy]')"
```

Then commit with: `git commit -m "fix: bug [skip-deploy]"`

## Common Scenarios

### Testing Locally Before Push

```bash
cd projects/my-project

# Run same tests that GitHub Actions will run
python -m pytest tests/
ruff check .
mypy src/

# If all pass, safe to push
git push
```

### Debugging a Failed Workflow

1. Go to GitHub Actions / Failed run
2. Read the error message
3. Run locally to reproduce: `python -m pytest tests/ -v`
4. Fix the issue
5. Push again

### Disabling a Workflow Temporarily

Rename the file:
```bash
mv .github/workflows/test.yml .github/workflows/test.yml.disabled
git push
```

Re-enable: rename `.disabled` back to `.yml`

## Integration with Wiggum Workers

When a Wiggum worker completes a task:

1. Worker commits changes: `git commit -m "Task: ..."`
2. Worker pushes: `git push`
3. GitHub Actions automatically runs workflows:
   - Tests execute
   - Staging deployment (if successful)
   - Notifications sent
4. Workers see test results in iteration logs

This creates a **fully autonomous CI/CD loop** where:
- Workers code → Git push → Tests run → Staging deploys → Production approval

## Troubleshooting

### Workflows Not Running

**Check:**
- Does `.github/workflows/` directory exist in project?
- Are you pushing to `main` or `develop` branch?
- Is GitHub Actions enabled for the repo?

**Fix:**
```bash
# Manually copy workflows if missing
cp -r /path/to/Free-Wiggum-opencode/.github/workflows projects/my-project/.github/
git add .github/
git commit -m "chore: add CI/CD workflows"
git push
```

### Tests Failing in CI but Passing Locally

**Common causes:**
- Different Python versions (check matrix in test.yml)
- Environment variables not set in GitHub
- File path issues (use relative paths)
- Missing dependencies

**Debug:**
```bash
# Reproduce GitHub's environment locally
python3.11 -m pytest tests/  # Use same version as GitHub Actions
```

### Deployment Failing

Check:
- SSH keys/deploy credentials configured?
- Environment URLs correct in secrets?
- Build artifacts generated?

## Advanced: Multi-Stage Deployments

To extend with additional environments (QA, UAT):

1. Create new workflow files:
   - `.github/workflows/deploy-qa.yml`
   - `.github/workflows/deploy-uat.yml`

2. Trigger on appropriate branches/tags:
   ```yaml
   on:
     push:
       branches: [ qa, uat ]
   ```

## Next Steps

1. First project creation will automatically include workflows
2. Commit and push to GitHub to trigger first CI/CD run
3. Monitor GitHub Actions tab to see results
4. Customize workflows as needed for your project

---

**Workflows are ready to go on your next project creation! 🚀**
