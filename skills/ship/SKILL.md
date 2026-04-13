---
name: ship
description: "Deploy to an environment (staging, production, etc.). Auto-discovers deployment mechanisms (GitHub Actions, branch pushes, CLI tools), ensures code is committed/pushed, validates deployment docs exist (creates them if missing), triggers the deploy, and monitors until healthy. Usage: /ship, /ship staging, /ship production."
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, WebFetch
---

# Ship

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling — including the `deployment` section which maps environments to their deploy mechanisms.

Deploy the current codebase to an environment. Auto-discovers how the project deploys, ensures everything is committed and pushed, validates deployment documentation exists, triggers the deployment, and monitors it until healthy.

## Usage

```
/ship                    # If only one environment exists, deploy to it. Otherwise, ask.
/ship staging            # Deploy to staging
/ship production         # Deploy to production
/ship develop            # Deploy to develop
```

## Workflow

<workflow>

### Step 1: Read Project Configuration

Read `project.config.yaml` and check for a `deployment` section:

```yaml
# Example deployment config in project.config.yaml
deployment:
  environments:
    staging:
      method: github_actions_workflow_dispatch
      workflow: deploy-staging.yml
      branch: develop
      url: https://staging.example.com
    production:
      method: github_actions_push
      branch: production
      url: https://api.example.com
```

If no `deployment` section exists, proceed to Step 2 to auto-discover.

### Step 2: Auto-Discover Deployment Mechanisms

If no deployment config exists, discover how the project deploys:

#### 2a. Check GitHub Actions workflows

```bash
ls .github/workflows/ 2>/dev/null
```

Look for files matching `deploy-*.yml`, `deploy_*.yml`, `release-*.yml`, `cd-*.yml`, or `publish-*.yml`. Read each to understand:
- **Trigger type**: `push` to branch, `workflow_dispatch`, `pull_request` merge
- **Target branch**: which branch triggers the deploy
- **Environment name**: extract from filename or workflow name

```bash
# For each deploy workflow, extract trigger info
grep -A5 "^on:" .github/workflows/deploy-*.yml
```

#### 2b. Check for other deployment methods

If no GitHub Actions found, check for:

```bash
# Makefile targets
grep -E "deploy|ship|release" Makefile 2>/dev/null

# Scripts
ls scripts/deploy* deploy* 2>/dev/null

# Docker Compose profiles
grep -E "deploy|prod|staging" docker-compose*.yml 2>/dev/null

# Platform-specific configs
ls fly.toml vercel.json netlify.toml railway.json render.yaml 2>/dev/null
ls apprunner.yaml ecs-params.yml serverless.yml 2>/dev/null
```

#### 2c. Build environment map

From the discovery, build a map of:
- Environment name (staging, production, develop, etc.)
- Deployment method (workflow_dispatch, push-to-branch, CLI command, etc.)
- Target branch (if applicable)
- Workflow file (if GitHub Actions)
- Health check URL (if discoverable)

### Step 3: Select Environment

If the user provided an environment name (e.g., `/ship staging`), use it.

If not provided:
- **One environment**: Use it automatically and inform the user.
- **Multiple environments**: List the discovered environments and ask the user which one to deploy to.

If the requested environment doesn't exist, list available environments and stop.

### Step 4: Pre-flight Checks

Before deploying, verify the codebase is ready:

#### 4a. Check for uncommitted changes

```bash
git status --porcelain
```

If there are uncommitted changes:
- Report what's uncommitted
- Ask the user: "There are uncommitted changes. Commit and push first? (This will use /commit-push)"
- If yes, invoke the commit-push workflow (stage, commit, push — including submodules)
- If no, stop and let the user handle it

#### 4b. Verify code is pushed

```bash
git log @{u}..HEAD --oneline 2>/dev/null
```

If there are unpushed commits:
- Report the unpushed commits
- Push them:
  ```bash
  git push
  ```
- If push fails, report the error and stop

#### 4c. Check CI status (if deploying via branch push or workflow)

```bash
gh run list --branch $(git branch --show-current) --limit 5
```

If the latest CI run failed, warn the user:
- "The latest CI run on this branch failed. Deploy anyway?"
- If they say no, stop

#### 4d. Check for pending migrations (if applicable)

If the project has a `commands.migrations` config:
```bash
# Check if there are migration files not yet in the target branch
git diff origin/<target-branch>..HEAD --name-only -- alembic/versions/ migrations/ db/migrate/
```

If new migrations exist, inform the user that the deploy will include database migrations.

### Step 5: Validate Deployment Documentation

Check if deployment docs exist:

```bash
# Check common doc locations
ls docs/deployment/ docs/deploy/ docs/infrastructure/ docs/ops/ 2>/dev/null
ls docs/DEPLOYMENT.md docs/DEPLOY.md DEPLOYMENT.md 2>/dev/null
```

Also check within the project's configured docs path from `project.config.yaml`:
```bash
ls {{config:paths.specs}}/*deploy* {{config:paths.specs}}/*ship* {{config:paths.specs}}/*infrastructure* 2>/dev/null
```

#### 5a. If deployment docs exist

Read them and verify they are up to date:
- Do the documented environments match what was discovered?
- Are the workflow names / branch names / URLs current?
- Is the deployment process description accurate?

If outdated, update them silently (fix the inaccuracies, don't ask).

#### 5b. If no deployment docs exist

Create `docs/deployment.md` with the following structure:

```markdown
# Deployment

## Environments

### [Environment Name]
- **Method**: [How it deploys — GitHub Actions, push-to-branch, etc.]
- **Trigger**: [What triggers a deploy]
- **Branch**: [Target branch, if applicable]
- **Workflow**: [Workflow file, if applicable]
- **URL**: [Service URL, if known]
- **Health Check**: [Health endpoint, if known]

[Repeat for each environment]

## How to Deploy

### Via /ship skill
```
/ship [environment]
```

### Manual deployment
[Step-by-step instructions based on discovered mechanisms]

## Rollback

[Instructions for rolling back, based on the deployment platform]

## Environment Variables

[Reference to where env vars are managed — .env_directory, GitHub Secrets, etc.]
```

Commit the new docs file:
```bash
git add docs/deployment.md
git commit -m "docs: add deployment documentation"
git push
```

### Step 6: Trigger Deployment

Based on the discovered deployment method:

#### Method: `github_actions_workflow_dispatch`

```bash
gh workflow run <workflow-file> --ref <current-branch>
```

Or with inputs if the workflow accepts them:
```bash
gh workflow run <workflow-file> --ref <current-branch> -f reason="Deployed via /ship"
```

#### Method: `github_actions_push` (push to target branch)

This means the workflow triggers on push to a specific branch. Merge or push to that branch:

```bash
# If current branch != target branch, we need to get code to the target branch
# Usually this means creating a PR or pushing directly

# Check if there's a PR workflow (e.g., staging deploys via PR merge)
# If so, create a PR:
gh pr create --base <target-branch> --head <current-branch> --title "Deploy to <environment>" --body "Triggered by /ship"

# If the workflow triggers on direct push, push to the branch:
git push origin HEAD:<target-branch>
```

**IMPORTANT**: Before pushing to a protected branch like `production`:
- Warn the user: "This will push to the `production` branch. Confirm?"
- Only proceed with explicit confirmation

#### Method: `makefile`

```bash
make deploy-<environment>
```

#### Method: `script`

```bash
./scripts/deploy-<environment>.sh
```

#### Method: `platform_cli` (Vercel, Fly, Railway, etc.)

```bash
# Vercel
vercel --prod

# Fly
fly deploy --config fly.toml

# Railway
railway up
```

### Step 7: Monitor Deployment

After triggering, monitor the deployment:

#### 7a. For GitHub Actions deployments

```bash
# Get the run ID of the just-triggered workflow
gh run list --workflow <workflow-file> --limit 1 --json databaseId,status,conclusion
```

Wait for it to complete:
```bash
gh run watch <run-id>
```

Or poll periodically:
```bash
gh run view <run-id> --json status,conclusion
```

Report progress:
- "Deployment started (run #<id>)..."
- "Build phase complete..."
- "Deployment in progress..."
- "Health check running..."

If the run fails:
```bash
# Get the failed job logs
gh run view <run-id> --log-failed
```

Report the failure and suggest next steps.

#### 7b. For branch-push deployments

After pushing, check if a workflow was triggered:
```bash
gh run list --branch <target-branch> --limit 1 --json databaseId,status,conclusion,workflowName
```

Monitor the triggered workflow as above.

#### 7c. Health check (if URL known)

After deployment completes successfully:

```bash
curl -s -o /dev/null -w "%{http_code}" <service-url>/health
```

Or use the project's configured health endpoint:
```bash
curl -s <service-url>{{config:api_testing.health_endpoint}}
```

### Step 8: Report Result

Report the deployment result:

```
Deployed to [environment]:
  Branch:    [branch]
  Commit:    [short sha] [message]
  Workflow:  [workflow run URL]
  Status:    [success/failed]
  Health:    [healthy/unhealthy/unknown]
  URL:       [service URL]
  Duration:  [how long the deploy took]
```

If the deployment included new migrations, note that.
If deployment docs were created or updated, note that too.

</workflow>

## Production Safety

Production deployments have extra guardrails:

1. **Always confirm** before deploying to production — even if the user typed `/ship production`
2. **Check CI**: If the latest CI run failed, block the deploy unless the user explicitly overrides
3. **Warn about migrations**: If new migrations are included, highlight them
4. **Never force-push** to a production branch
5. **Log the deployment**: Note the commit SHA, timestamp, and who triggered it

## Error Recovery

| Scenario | Action |
|----------|--------|
| Workflow dispatch fails (404) | Check if workflow file exists and has `workflow_dispatch` trigger |
| Push to branch rejected | Pull --rebase and retry; if conflicts, report and stop |
| Workflow run fails | Show failed job logs, suggest fixes |
| Health check fails after deploy | Warn user, suggest checking logs or rolling back |
| No deployment mechanism found | Report findings and ask the user how their project deploys |

## Important Notes

- This skill is **project-agnostic** — it discovers how each project deploys rather than hardcoding any mechanism
- The `deployment` section in `project.config.yaml` is optional but recommended for faster execution
- If no config exists, discovery runs every time (adds a few seconds)
- For production: always confirm, always check CI, always monitor
- For staging: confirm only if there are warnings (failed CI, uncommitted changes)
- **NEVER add AI attribution** to any commits created during the ship process
- The skill creates deployment docs if they don't exist — this is a one-time setup cost that pays for itself
