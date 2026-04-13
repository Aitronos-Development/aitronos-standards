---
name: security-fix
description: Check Dependabot security alerts, upgrade vulnerable dependencies, and report what was fixed vs what needs manual attention.
disable-model-invocation: false
user-invocable: true
---

# Security Fix Skill

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling. The dependency management and test commands referenced below come from that file.

Scan Dependabot security alerts for the repository, automatically upgrade vulnerable dependencies to patched versions, run tests to verify nothing breaks, and produce a summary table of results.

## When to Use

- Regular security maintenance (weekly/monthly)
- Before releases or deployments
- When Dependabot alerts appear in GitHub
- After a security advisory is published for a dependency
- When CI/CD security checks fail

## What This Does

1. **Fetches all open Dependabot security alerts** from GitHub
2. **Analyzes each alert** — severity, affected package, patched version
3. **Attempts automatic upgrades** using the project's package manager
4. **Runs tests** after each upgrade to catch breakage
5. **Rolls back** upgrades that cause test failures
6. **Reports results** in a clear table showing what was fixed, what failed, and what needs manual work

## Usage

User invocation:
```
/security-fix
```

Or with options:
```
/security-fix --dry-run       # Report only, don't upgrade anything
/security-fix --severity high # Only fix high/critical severity alerts
/security-fix --skip-tests    # Upgrade without running tests (faster, riskier)
```

## Workflow

<workflow>

### Step 1: Fetch Dependabot Security Alerts

Use `gh` CLI to get all open Dependabot alerts:

```bash
gh api repos/:owner/:repo/dependabot/alerts --jq '[.[] | select(.state == "open") | {number: .number, package: .security_vulnerability.package.name, ecosystem: .security_vulnerability.package.ecosystem, severity: .security_advisory.severity, summary: .security_advisory.summary, fixed_in: .security_vulnerability.first_patched_version.identifier, vulnerable_range: .security_vulnerability.vulnerable_version_range, cve: .security_advisory.cve_id, url: .html_url}]'
```

If the `--severity` flag is provided, filter by severity level (only process alerts matching that level or higher). Severity hierarchy: critical > high > medium > low.

If `--dry-run` is provided, skip to Step 5 and report the current state without making changes.

### Step 2: Check Current Installed Versions

For each alert, check what version is currently installed:

```bash
{{config:commands.deps.show}} <package-name>
```

Also check if the package is a direct dependency or transitive:

```bash
grep -i '<package-name>' {{config:paths.deps_file}}
```

Categorize each alert:
- **Direct dependency**: Listed in `{{config:paths.deps_file}}` — can upgrade directly
- **Transitive dependency**: Not in `{{config:paths.deps_file}}` — may need parent package upgrade
- **Already fixed**: Installed version >= patched version — just needs alert dismissal

### Step 3: Attempt Upgrades

For each unfixed alert, attempt the upgrade in order of severity (critical first, then high, medium, low):

**For direct dependencies:**
```bash
{{config:commands.deps.add}} "<package-name>>=<patched-version>"
{{config:commands.deps.lock}}
{{config:commands.deps.install}}
```

**For transitive dependencies:**
First, find which direct dependency pulls it in:
```bash
{{config:commands.deps.show}} <package-name>
```

Then upgrade the parent package or use a resolution override as supported by the project's package manager.

If the patched version is not available or the constraint conflicts, note it as "cannot auto-fix" and move on.

### Step 4: Run Tests After Upgrades

Unless `--skip-tests` is specified, run the test suite after upgrades:

```bash
{{config:commands.test.all}} -x -q --timeout=120 -m "not slow and not e2e"
```

If tests fail:
1. Identify which upgrade caused the failure
2. Roll back that specific upgrade:
   ```bash
   {{config:commands.deps.add}} "<package-name>==<original-version>"
   {{config:commands.deps.lock}}
   {{config:commands.deps.install}}
   ```
3. Mark the alert as "upgrade breaks tests — needs manual fix"
4. Continue with remaining alerts

If tests pass, the upgrade is confirmed.

### Step 5: Verify Alert Resolution

For each upgraded package, verify the installed version now satisfies the patched version:

```bash
{{config:commands.deps.show}} <package-name>
```

### Step 6: Generate Summary Report

Produce a markdown table summarizing all results:

```
## Security Fix Report

### Summary
- **Total open alerts**: X
- **Fixed automatically**: Y
- **Could not fix**: Z
- **Already fixed**: W

### Results

| # | Package | Severity | Vulnerability | Patched In | Status | Notes |
|---|---------|----------|---------------|------------|--------|-------|
| 33 | pypdf | medium | RunLengthDecode RAM exhaust | 6.7.4 | Fixed | Upgraded to 6.7.4 |
| 26 | pillow | high | OOB write loading PSD | 12.1.1 | Fixed | Upgraded to 12.1.1 |
| 31 | langgraph-checkpoint | medium | Deserialization RCE | 4.0.0 | Failed | Tests broke — needs manual review |
| 20 | python-multipart | high | Arbitrary file write | 0.0.22 | Transitive | Upgrade parent package |

### Alerts That Need Manual Attention

For each unfixed alert, explain:
- **Why it couldn't be auto-fixed** (version conflict, test failure, transitive dep, etc.)
- **Suggested manual action** (upgrade parent, pin version, wait for upstream fix, etc.)
- **Link to the alert** for more context
```

Report the table to the user.

### Step 7: Offer to Commit

If any upgrades were applied, offer to commit the changes:

```bash
git diff {{config:paths.deps_file}} {{config:paths.lock_file}}
```

If the user agrees, commit with a descriptive message:

```bash
git add {{config:paths.deps_file}} {{config:paths.lock_file}}
git commit -m "$(cat <<'EOF'
deps(security): upgrade vulnerable dependencies

Fixes Dependabot alerts: #N, #M, ...
Packages upgraded: package1 (x.y.z -> a.b.c), package2 (...)
EOF
)"
```

</workflow>

## Severity Levels

| Severity | Priority | Action |
|----------|----------|--------|
| Critical | Immediate | Always upgrade, even if tests are uncertain |
| High | Urgent | Upgrade and verify with tests |
| Medium | Normal | Upgrade if safe |
| Low | Low | Upgrade opportunistically |

## Key Paths

- **Dependabot config**: `.github/dependabot.yml`
- **Dependencies file**: `{{config:paths.deps_file}}`
- **Lock file**: `{{config:paths.lock_file}}`

## Integration

This skill works with:
- GitHub Dependabot alerts API (`gh api`)
- Project package manager (as defined in `project.config.yaml`)
- Project test suite
- Git for committing fixes

## Notes

- Always run tests after upgrades to catch breaking changes
- Transitive dependency upgrades may require upgrading parent packages
- Some alerts may not be fixable if the patched version is incompatible
- Check `gh api repos/:owner/:repo/dependabot/alerts` for raw alert data
- Use `--dry-run` first to see what would be changed before making modifications
- Check `project.config.yaml` for the exact dependency management commands for your project
